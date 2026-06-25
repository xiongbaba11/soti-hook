#!/usr/bin/env python3
"""
正确的dylib注入 - 修复所有文件偏移
"""
import struct, sys, shutil, os, zipfile, tempfile, plistlib

def inject_dylib(binary_path, dylib_path):
    with open(binary_path, 'rb') as f:
        data = bytearray(f.read())
    
    magic = struct.unpack_from('<I', data, 0)[0]
    if magic != 0xFEEDFACF:
        print(f"错误: 不是64位Mach-O (magic=0x{magic:08x})")
        return False
    
    ncmds = struct.unpack_from('<I', data, 16)[0]
    sizeofcmds = struct.unpack_from('<I', data, 20)[0]
    insert_offset = 32 + sizeofcmds  # load commands末尾
    
    # 检查是否已注入
    off = 32
    for _ in range(ncmds):
        cmd, sz = struct.unpack_from('<II', data, off)
        if cmd in (0x0C, 0x80000028):
            name_off = struct.unpack_from('<I', data, off+8)[0]
            name_end = data.index(b'\x00', off + name_off)
            name = data[off+name_off:name_end].decode()
            if dylib_path.split('/')[-1] in name:
                print(f"已注入: {name}")
                return True
        off += sz
    
    # 构建LC_LOAD_DYLIB
    name_bytes = dylib_path.encode() + b'\x00'
    unpadded = 24 + len(name_bytes)
    padded = (unpadded + 7) & ~7
    cmdsize = padded
    
    new_cmd = struct.pack('<II', 0x0C, cmdsize)
    new_cmd += struct.pack('<I', 24)        # name offset
    new_cmd += struct.pack('<I', 2)         # timestamp
    new_cmd += struct.pack('<I', 0x10000)   # current_version
    new_cmd += struct.pack('<I', 0x10000)   # compat_version
    new_cmd += name_bytes
    new_cmd += b'\x00' * (padded - unpadded)
    
    # 插入新command
    new_data = bytearray(data[:insert_offset])
    new_data.extend(new_cmd)
    new_data.extend(data[insert_offset:])
    
    # 更新header
    struct.pack_into('<I', new_data, 16, ncmds + 1)
    struct.pack_into('<I', new_data, 20, sizeofcmds + cmdsize)
    
    # ===== 关键: 修复所有文件偏移 =====
    delta = cmdsize
    off = 32
    for i in range(ncmds + 1):  # +1 因为新command也在里面
        cmd, sz = struct.unpack_from('<II', new_data, off)
        if sz == 0: break
        
        if cmd == 0x19:  # LC_SEGMENT_64
            fileoff = struct.unpack_from('<Q', new_data, off + 40)[0]
            if fileoff >= insert_offset:
                new_fileoff = fileoff + delta
                struct.pack_into('<Q', new_data, off + 40, new_fileoff)
            
            # 修复section offsets
            nsects = struct.unpack_from('<I', new_data, off + 64)[0]
            sect_off = off + 72  # segment_command后第一个section
            for j in range(nsects):
                sect_fileoff = struct.unpack_from('<I', new_data, sect_off + 48)[0]
                if sect_fileoff >= insert_offset:
                    struct.pack_into('<I', new_data, sect_off + 48, sect_fileoff + delta)
                sect_off += 80  # section_64 size
        
        elif cmd == 0x29:  # LC_CODE_SIGNATURE
            dataoff = struct.unpack_from('<I', new_data, off + 8)[0]
            if dataoff >= insert_offset:
                struct.pack_into('<I', new_data, off + 8, dataoff + delta)
        
        elif cmd == 0x26:  # LC_FUNCTION_STARTS
            dataoff = struct.unpack_from('<I', new_data, off + 8)[0]
            if dataoff >= insert_offset:
                struct.pack_into('<I', new_data, off + 8, dataoff + delta)
        
        elif cmd == 0x2C:  # LC_DATA_IN_CODE
            dataoff = struct.unpack_from('<I', new_data, off + 8)[0]
            if dataoff >= insert_offset:
                struct.pack_into('<I', new_data, off + 8, dataoff + delta)
        
        elif cmd == 0x2D:  # LC_LINKER_OPTIMIZATION_HINT
            dataoff = struct.unpack_from('<I', new_data, off + 8)[0]
            if dataoff >= insert_offset:
                struct.pack_into('<I', new_data, off + 8, dataoff + delta)
        
        off += sz
    
    with open(binary_path, 'wb') as f:
        f.write(new_data)
    
    print(f"✓ 注入成功: {dylib_path}")
    return True

def main():
    ipa = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 else ipa.replace('.ipa', '_hooked.ipa')
    dylib_name = 'sotihook.dylib'
    
    with tempfile.TemporaryDirectory() as tmp:
        with zipfile.ZipFile(ipa, 'r') as z:
            z.extractall(tmp)
        
        app = next(os.path.join(tmp, 'Payload', d) 
                   for d in os.listdir(os.path.join(tmp, 'Payload')) 
                   if d.endswith('.app'))
        
        # 复制dylib
        dylib_src = os.path.join(os.path.dirname(__file__), dylib_name)
        shutil.copy2(dylib_src, os.path.join(app, dylib_name))
        
        # 找主二进制
        with open(os.path.join(app, 'Info.plist'), 'rb') as f:
            plist = plistlib.load(f)
        
        exe = os.path.join(app, plist['CFBundleExecutable'])
        
        # 注入
        inject_dylib(exe, f'@executable_path/{dylib_name}')
        
        # 打包
        with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
            for r, _, fs in os.walk(tmp):
                for f in fs:
                    p = os.path.join(r, f)
                    z.write(p, os.path.relpath(p, tmp))
        
        print(f"输出: {out} ({os.path.getsize(out)/1024/1024:.1f}MB)")

if __name__ == '__main__':
    main()
