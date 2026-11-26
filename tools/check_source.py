#!/usr/bin/env python3
import importlib.util,io,pathlib,plistlib,shutil,subprocess,tarfile,tempfile
ROOT=pathlib.Path(__file__).resolve().parents[1]
def check():
 source=(ROOT/'Sources/NB27Banner.m').read_text()
 assert 'removeAllAnimations' not in source
 for name in ['NB27OriginalAnimate','NB27OriginalAdd','NB27OriginalWillDisappear','NB27OriginalDidDisappear','NB27OriginalInteraction','NB27OriginalViewInteraction','NB27OriginalLongLook']:
  assert source.count('static void (*'+name+')')==1,name
 assert '*done=YES;hook(' in source
 assert source.index('s.active=NO;')<source.index('NB27RemoveCardAnimations(s.card);')
 assert 'if(self.exiting&&finished)return;' in source
 assert 'method_copyArgumentType' in source and 'method_copyReturnType' in source
 assert 's.deadline' in source and 'NB27Clamp' in source
 forbidden=['GAXConfigureNotificationGlass','UIVisualEffectView','CAFilter','MTLCreateSystemDefaultDevice','NotificationIOS26Enabled']
 for item in forbidden:assert item not in source,item
 p=lambda name:plistlib.loads((ROOT/'Resources'/name).read_bytes())
 assert p('NB27Banner.plist')=={'Filter':{'Bundles':['com.apple.springboard']}}
 entry=p('entry.plist')['entry'];assert entry['isController'] and entry['detail']=='NB27Preferences'
 root=p('Root.plist');assert isinstance(root,dict)
 switches=[x for x in root['items'] if x['cell']=='PSSwitchCell']
 assert len(switches)==1 and switches[0]['key']=='Enabled' and switches[0]['default'] is True
 groups=[x['label'] for x in root['items'] if x['cell']=='PSGroupCell']
 sliders={x['key']:x for x in root['items'] if x['cell']=='PSSliderCell'}
 assert groups==['通知横幅动画','动画弹性','转场时长']
 assert set(sliders)=={'Elasticity','TransitionScale'}
 assert sliders['Elasticity']['default']==1.0 and sliders['Elasticity']['min']==0 and sliders['Elasticity']['max']==2
 assert sliders['TransitionScale']['default']==1.0 and sliders['TransitionScale']['min']==.5 and sliders['TransitionScale']['max']==2
 assert root['items'][0]['footerText']=='iOS27横幅进出场动画开启“减弱动态效果”时回退原生动画。'
 assert p('Info.plist')['NSPrincipalClass']==entry['detail']
 info=p('Info.plist');assert info['CFBundleShortVersionString']==info['CFBundleVersion']=='0.4'
 build_text=(ROOT/'tools/build.py').read_text()
 assert "VERSION='0.4';PACKAGE='com.ning.27banneranimation'" in build_text
 assert 'Maintainer: Ning\\nAuthor: Ning\\n' in build_text
 workflow=(ROOT/'.github/workflows/build.yml').read_text()
 assert '\non:\n  workflow_dispatch:' in workflow
 assert '\n  push:' not in workflow and '\n  pull_request:' not in workflow
 assert 'macos-latest' in workflow
 with tempfile.TemporaryDirectory() as td:
  binary=pathlib.Path(td)/'motion-tests'
  subprocess.run([shutil.which('clang') or 'cc','-std=c11','-O2','-Wall','-Wextra','-Werror',str(ROOT/'tests/test_motion.c'),'-lm','-o',str(binary)],check=True)
  subprocess.run([str(binary)],check=True)
 spec=importlib.util.spec_from_file_location('nb27_build',ROOT/'tools/build.py');module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
 contents=module.archive({'usr/lib/test':(b'fixture',0o755),'Library/Preferences/entry':(b'fixture2',0o644)})
 with tarfile.open(fileobj=io.BytesIO(contents),mode='r:xz') as tar:
  members=tar.getmembers();assert all(x.uid==0 and x.gid==0 for x in members)
  assert any(x.isdir() and x.name=='./usr/lib' for x in members)
  assert tar.extractfile('./usr/lib/test').read()==b'fixture'
 member=module.ar_member('debian-binary',b'2.0\n');assert len(member)==64 and member[58:60]==b'`\n'
 print('PASS: single feature, native resource structure, seven original slots, manual-only workflow, dpkg directory/ownership fixture')
if __name__=='__main__':check()
