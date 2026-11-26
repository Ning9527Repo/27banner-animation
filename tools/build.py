#!/usr/bin/env python3
"""Manual macOS/Xcode build. No network, installing, respring, or CI dispatch."""
import argparse,hashlib,io,json,pathlib,plistlib,shutil,struct,subprocess,tarfile
ROOT=pathlib.Path(__file__).resolve().parents[1]
VERSION='0.2';PACKAGE='com.ning.27banneranimation'
def run(args):subprocess.run([str(x) for x in args],check=True,cwd=ROOT)
def ar_member(name,data):
 header=(name+'/').ljust(16)+'0'.ljust(12)+'0'.ljust(6)+'0'.ljust(6)+'100644'.ljust(8)+str(len(data)).ljust(10)+'`\n'
 assert len(header)==60
 return header.encode('ascii')+data+(b'\n' if len(data)%2 else b'')
def archive(files):
 out=io.BytesIO()
 with tarfile.open(fileobj=out,mode='w:xz',preset=9) as tar:
  # Explicit directories are required by iOS dpkg; uid/gid must be 0, not CI user's IDs.
  paths={'.'}
  for path in files:
   parts=pathlib.PurePosixPath(path).parts
   for n in range(1,len(parts)):paths.add('/'.join(parts[:n]))
  for path in sorted(paths,key=lambda p:(p.count('/'),p)):
   info=tarfile.TarInfo('./'+path if path!='.' else './');info.type=tarfile.DIRTYPE;info.mode=0o755
   info.uid=info.gid=0;info.uname=info.gname='root';info.mtime=0;tar.addfile(info)
  for path,(data,mode) in sorted(files.items()):
   info=tarfile.TarInfo('./'+path);info.size=len(data);info.mode=mode
   info.uid=info.gid=0;info.uname=info.gname='root';info.mtime=0;tar.addfile(info,io.BytesIO(data))
 return out.getvalue()
def check_binary(path,arch):
 data=path.read_bytes();magic,cpu,sub=struct.unpack_from('<III',data)
 expected=0x80000002 if arch=='arm64e' else 0
 if magic!=0xfeedfacf or cpu!=0x100000c or sub!=expected:raise ValueError(f'Wrong real Mach-O architecture: {path.name}: {sub:#x}')
 run(['codesign','--verify','--strict',path]);return {'size':len(data),'sha256':hashlib.sha256(data).hexdigest(),'cpusubtype':hex(sub)}
def build(arch,sdk):
 out=ROOT/'out'/arch;out.mkdir(parents=True,exist_ok=True)
 flags=['xcrun','--sdk','iphoneos','clang','-target',arch+'-apple-ios15.0','-isysroot',sdk,
  '-fobjc-arc','-fblocks','-O2','-Wall','-Wextra','-Werror','-Wno-unused-parameter',
  '-dynamiclib','-framework','Foundation','-framework','UIKit','-framework','QuartzCore','-framework','CoreGraphics']
 main=out/'NB27Banner.dylib';prefs=out/'NB27Preferences'
 run(flags+[ROOT/'Sources/NB27Banner.m',ROOT/'Sources/NB27Compact.m','-o',main])
 # PSListController is supplied by the Settings host; no fake Preferences framework binary.
 run(flags+['-Wl,-undefined,dynamic_lookup',ROOT/'Preferences/NB27Preferences.m','-o',prefs])
 reports={}
 for binary in (main,prefs):
  run(['codesign','--force','--sign','-',binary]);reports[binary.name]=check_binary(binary,arch)
 prefix='' if arch=='arm64e' else 'var/jb/'
 data={}
 def add(path,content,mode=0o644):data[prefix+path]=(content,mode)
 add('usr/lib/TweakInject/NB27Banner.dylib',main.read_bytes(),0o755)
 add('usr/lib/TweakInject/NB27Banner.plist',(ROOT/'Resources/NB27Banner.plist').read_bytes())
 add('Library/PreferenceLoader/Preferences/NB27Banner.plist',(ROOT/'Resources/entry.plist').read_bytes())
 bundle='Library/PreferenceBundles/NB27Preferences.bundle/'
 add(bundle+'NB27Preferences',prefs.read_bytes(),0o755)
 for name in ('Info.plist','Root.plist'):add(bundle+name,(ROOT/'Resources'/name).read_bytes())
 add('usr/share/doc/'+PACKAGE+'/NOTICE',(ROOT/'NOTICE.md').read_bytes())
 for file in sorted((ROOT/'Licenses').glob('*')):add('usr/share/doc/'+PACKAGE+'/Licenses/'+file.name,file.read_bytes())
 architecture='iphoneos-'+arch
 control=f'Package: {PACKAGE}\nName: 27banner animation\nVersion: {VERSION}\nArchitecture: {architecture}\nDescription: Standalone reconstructed iOS 27 banner motion for iOS 15-17.\nMaintainer: Ning\nAuthor: Ning\nSection: Tweaks\nDepends: firmware (>= 15.0), firmware (<< 18.0), mobilesubstrate, preferenceloader\n'
 checks=''.join(hashlib.md5(content).hexdigest()+'  '+path+'\n' for path,(content,mode) in sorted(data.items()))
 payload=b'!<arch>\n'+ar_member('debian-binary',b'2.0\n')+ar_member('control.tar.xz',archive({'control':(control.encode(),0o644),'md5sums':(checks.encode(),0o644)}))+ar_member('data.tar.xz',archive(data))
 package=ROOT/'out'/f'{PACKAGE}_{VERSION}_{architecture}.deb';package.write_bytes(payload)
 return {'arch':arch,'file':package.name,'size':len(payload),'sha256':hashlib.sha256(payload).hexdigest(),'binaries':reports}
def main():
 parser=argparse.ArgumentParser();parser.add_argument('--arch',choices=['both','arm64','arm64e'],default='both');args=parser.parse_args()
 sdk=subprocess.check_output(['xcrun','--sdk','iphoneos','--show-sdk-path'],text=True).strip()
 run(['python3','tools/generate_resources.py']);run(['python3','tools/check_source.py'])
 reports=[build(a,sdk) for a in (['arm64','arm64e'] if args.arch=='both' else [args.arch])]
 (ROOT/'out/verification.json').write_text(json.dumps(reports,indent=2)+'\n');print(json.dumps(reports,indent=2))
if __name__=='__main__':main()
