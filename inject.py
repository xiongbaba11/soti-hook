#!/usr/bin/env python3
"""
注入自定义dylib到IPA (不用Frida，直接注入sotihook.dylib)
"""

import os, sys, struct, shutil, zipfile, tempfile, plistlib

def read_header(data):
    magic = struct.unpack_from('<I', data, 0)[0]
    if magic == 0xFEEDFACF:
        return {'ncmds': struct.unpack_from('<I', data, 16)[0],
                'sizeofcmds': struct.unpack_from('<I', data, 20)[0], 'hdr': 32}
    return None

def has_dylib(data, name):
    h = read_header(data)
    if not h: return False
    off = h['hdr']
    for _ in range(h['ncmds']):
        cmd = struct.unpack_from('<I', data, off)[0]
        sz = struct.unpack_from('<I', data, off+4)[0]
        if sz == 0: break
        if cmd in (0xC, 0x80000018):
            n_off = struct.unpack_from('<I', data, off+8)[0]
            end = data.find(b'\x00', off+n_off)
            lib = data[off+n_off:end].decode('utf-8', errors='replace')
            if name in lib: return True
        off += sz
    return False

def inject(data, path):
    h = read_header(data)
    if not h: return None
    if has_dylib(data, path): return data
    nb = path.encode() + b'\x00'
    pl = (len(nb)+7)&~7
    cs = (24+pl+7)&~7
    cmd = bytearray(cs)
    struct.pack_into('<I', cmd, 0, 0xC)
    struct.pack_into('<I', cmd, 4, cs)
    struct.pack_into('<I', cmd, 8, 24)
    cmd[24:24+len(nb)] = nb
    end = h['hdr'] + h['sizeofcmds']
    d = bytearray(data)
    struct.pack_into('<I', d, 16, h['ncmds']+1)
    struct.pack_into('<I', d, 20, h['sizeofcmds']+cs)
    d[end:end] = bytes(cmd)
    return bytes(d)

def main():
    ipa = sys.argv[1]
    out = sys.argv[2] if len(sys.argv)>2 else ipa.replace('.ipa','_hooked.ipa')
    dylib = sys.argv[3] if len(sys.argv)>3 else os.path.join(os.path.dirname(__file__), 'sotihook.dylib')
    
    if not os.path.exists(dylib):
        print(f"错误: 找不到 {dylib}")
        print("用法: python inject.py input.ipa [output.ipa] [sotihook.dylib]")
        sys.exit(1)
    
    with tempfile.TemporaryDirectory() as tmp:
        with zipfile.ZipFile(ipa,'r') as z: z.extractall(tmp)
        app = next(os.path.join(tmp,'Payload',d) for d in os.listdir(os.path.join(tmp,'Payload')) if d.endswith('.app'))
        
        # 复制dylib
        shutil.copy2(dylib, os.path.join(app, 'sotihook.dylib'))
        
        # 注入主二进制
        with open(os.path.join(app,'Info.plist'),'rb') as f: plist = plistlib.load(f)
        exe = os.path.join(app, plist['CFBundleExecutable'])
        with open(exe,'rb') as f: binary = f.read()
        
        new = inject(binary, '@executable_path/sotihook.dylib')
        if new:
            with open(exe,'wb') as f: f.write(new)
            print("注入成功!")
        
        with zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED) as z:
            for r,_,fs in os.walk(tmp):
                for f in fs:
                    p = os.path.join(r,f)
                    z.write(p, os.path.relpath(p,tmp))
        
        print(f"输出: {out} ({os.path.getsize(out)/1024/1024:.1f}MB)")

if __name__=='__main__': main()
