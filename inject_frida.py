#!/usr/bin/env python3
"""注入 FridaGadget 到 IPA (listen模式，更稳定)"""

import os, sys, struct, shutil, zipfile, tempfile, json, plistlib

def read_macho_header(data):
    magic = struct.unpack_from('<I', data, 0)[0]
    if magic == 0xFEEDFACF:
        return {'ncmds': struct.unpack_from('<I', data, 16)[0], 
                'sizeofcmds': struct.unpack_from('<I', data, 20)[0], 'header_size': 32}
    return None

def has_dylib(data, name):
    header = read_macho_header(data)
    if not header: return False
    offset = header['header_size']
    for _ in range(header['ncmds']):
        cmd = struct.unpack_from('<I', data, offset)[0]
        cmdsize = struct.unpack_from('<I', data, offset + 4)[0]
        if cmdsize == 0: break
        if cmd in (0xC, 0x80000018):
            name_off = struct.unpack_from('<I', data, offset + 8)[0]
            end = data.find(b'\x00', offset + name_off)
            lib = data[offset + name_off:end].decode('utf-8', errors='replace')
            if name in lib: return True
        offset += cmdsize
    return False

def inject_dylib(data, dylib_path):
    header = read_macho_header(data)
    if not header: return None
    if has_dylib(data, dylib_path):
        return data
    name_bytes = dylib_path.encode('utf-8') + b'\x00'
    padded_len = (len(name_bytes) + 7) & ~7
    cmdsize = (24 + padded_len + 7) & ~7
    cmd_data = bytearray(cmdsize)
    struct.pack_into('<I', cmd_data, 0, 0xC)
    struct.pack_into('<I', cmd_data, 4, cmdsize)
    struct.pack_into('<I', cmd_data, 8, 24)
    cmd_data[24:24 + len(name_bytes)] = name_bytes
    cmds_end = header['header_size'] + header['sizeofcmds']
    new_data = bytearray(data)
    struct.pack_into('<I', new_data, 16, header['ncmds'] + 1)
    struct.pack_into('<I', new_data, 20, header['sizeofcmds'] + cmdsize)
    new_data[cmds_end:cmds_end] = bytes(cmd_data)
    return bytes(new_data)

def main():
    input_ipa = sys.argv[1]
    output_ipa = sys.argv[2] if len(sys.argv) > 2 else input_ipa.replace('.ipa', '_frida.ipa')
    script_dir = os.path.dirname(os.path.abspath(__file__))
    frida_dylib = os.path.join(script_dir, 'FridaGadget_arm64.dylib')
    hook_script = os.path.join(script_dir, 'sotihook.js')
    
    with tempfile.TemporaryDirectory() as tmpdir:
        with zipfile.ZipFile(input_ipa, 'r') as zf:
            zf.extractall(tmpdir)
        
        app_dir = next(os.path.join(tmpdir, 'Payload', d) 
                       for d in os.listdir(os.path.join(tmpdir, 'Payload')) 
                       if d.endswith('.app'))
        
        shutil.copy2(frida_dylib, os.path.join(app_dir, 'FridaGadget.dylib'))
        if os.path.exists(hook_script):
            shutil.copy2(hook_script, os.path.join(app_dir, 'sotihook.js'))
        
        # listen模式 - 启动后暂停等连接
        config = {
            "interaction": {
                "type": "listen",
                "address": "127.0.0.1",
                "port": 27042,
                "on_load": "resume"
            }
        }
        with open(os.path.join(app_dir, 'frida-gadget.config'), 'w') as f:
            json.dump(config, f, indent=2)
        
        with open(os.path.join(app_dir, 'Info.plist'), 'rb') as f:
            plist = plistlib.load(f)
        
        exec_path = os.path.join(app_dir, plist['CFBundleExecutable'])
        with open(exec_path, 'rb') as f:
            binary = f.read()
        
        new_binary = inject_dylib(binary, '@executable_path/FridaGadget.dylib')
        if new_binary:
            with open(exec_path, 'wb') as f:
                f.write(new_binary)
            print("注入成功!")
        
        with zipfile.ZipFile(output_ipa, 'w', zipfile.ZIP_DEFLATED) as zf:
            for root, dirs, files in os.walk(tmpdir):
                for file in files:
                    fp = os.path.join(root, file)
                    zf.write(fp, os.path.relpath(fp, tmpdir))
        
        print(f"输出: {output_ipa} ({os.path.getsize(output_ipa)/1024/1024:.1f}MB)")

if __name__ == '__main__':
    main()
