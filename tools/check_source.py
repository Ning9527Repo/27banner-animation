#!/usr/bin/env python3
import importlib.util,io,pathlib,plistlib,shutil,subprocess,tarfile,tempfile
ROOT=pathlib.Path(__file__).resolve().parents[1]
def check():
 source=(ROOT/'Sources/NB27Banner.m').read_text()
 assert 'removeAllAnimations' not in source
 for name in ['NB27OriginalAnimate','NB27OriginalAdd','NB27OriginalWillDisappear','NB27OriginalDidDisappear','NB27OriginalInteraction','NB27OriginalViewInteraction','NB27OriginalLongLook']:
  assert source.count('static void (*'+name+')')==1,name
 assert '*done=YES;hook(' in source
 end=source[source.index('static void NB27End(NB27Session *s) {'):source.index('\nstatic void NB27ClearController(UIViewController *c) {')]
 assert end.index('s.active=NO;')<end.index('NB27RemoveCardAnimations(s.card);')
 assert 'if(self.exiting)' in source
 assert 'if(self.transitionContext.transitionWasCancelled)NB27End(self);' in source
 delegate=source[source.index('-(void)animationDidStop:'):source.index('\n@end',source.index('-(void)animationDidStop:'))]
 assert 'NB27CompactFinishExit' not in delegate
 did=source[source.index('static void NB27DidDisappear('):source.index('static void NB27CancelForObject(')]
 assert '!s.transitionContext.transitionWasCancelled' in did
 assert did.index('NB27CompactFinishExit')<did.index('NB27OriginalDidDisappear')
 assert 'NB27CompactSetEnabled(enabled)' in source and 'NB27CompactAbortExit(s.compactTicket)' in source
 assert 'pending.compactDX=old.compactDX' in source and 'pending.compactDY=old.compactDY' in source
 assert 'originSource=reusable?pending:' in source
 assert 's.compactDX=dx;s.compactDY=dy;s.motionOriginReady=YES;' in source
 assert 'pending.transitionGeneration==previousFromGeneration' in source
 assert 'NB27CancelPendingForTransition(c,generation);return;' in source
 assert 'strong.retentionOnly=YES;NB27ReleaseExitVisual(strong);NB27Expire(strong,4.0);' in source
 assert 'remaining<.08' not in source
 assert not any(x in source for x in ('NB27Elasticity','NB27ElasticMotion'))
 compact=(ROOT/'Sources/NB27Compact.m').read_text()
 assert 'if (HaveAnchor && (!TimeItem || !TimeLabel || !source ||' in compact
 assert '_UIStatusBarStringView' in compact and 'static UIColor *CompactTextColor' in compact
 assert '!CompactCapture(TimeItem, TimeLabel))) CompactClearAnchor();' in compact
 assert '- (BOOL)canBecomeKeyWindow { return NO; }' in compact
 assert 'return nil; }' in compact and 'Window.userInteractionEnabled = NO' in compact
 assert 'SBLockScreenManager' in compact and 'isUILocked' in compact
 assert 'com.apple.springboard.lockstate' in compact
 assert not any(x in compact for x in ('makeKeyAndVisible','MSHookMessageEx','method_setImplementation','removeAllAnimations'))
 assert 'method_copyArgumentType' in source and 'method_copyReturnType' in source
 assert 's.deadline' in source and 'NB27Clamp' in source
 forbidden=['GAXConfigureNotificationGlass','UIVisualEffectView','CAFilter','MTLCreateSystemDefaultDevice','NotificationIOS26Enabled']
 for item in forbidden:assert item not in source,item
 p=lambda name:plistlib.loads((ROOT/'Resources'/name).read_bytes())
 assert p('NB27Banner.plist')=={'Filter':{'Bundles':['com.apple.springboard']}}
 entry=p('entry.plist')['entry'];assert entry['isController'] and entry['detail']=='NB27Preferences'
 root=p('Root.plist');assert isinstance(root,dict)
 assert root['items'][0]['footerText']=='iOS 27 横幅进出场动画。开启“减弱动态效果”时回退原生动画。'
 switches=[x for x in root['items'] if x['cell']=='PSSwitchCell']
 assert len(switches)==1 and switches[0]['key']=='Enabled' and switches[0]['default'] is True
 assert p('Info.plist')['NSPrincipalClass']==entry['detail']
 workflow=(ROOT/'.github/workflows/build.yml').read_text()
 assert '\non:\n  workflow_dispatch:' in workflow
 assert '\n  push:' not in workflow and '\n  pull_request:' not in workflow
 assert 'macos-latest' in workflow
 with tempfile.TemporaryDirectory() as td:
  for name in ('motion','reference_motion','compact'):
   binary=pathlib.Path(td)/(name+'-tests')
   subprocess.run([shutil.which('clang') or 'cc','-std=c11','-O2','-Wall','-Wextra','-Werror',str(ROOT/('tests/test_'+name+'.c')),'-lm','-o',str(binary)],check=True)
   subprocess.run([str(binary)],check=True)
 spec=importlib.util.spec_from_file_location('nb27_build',ROOT/'tools/build.py');module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
 info=p('Info.plist');assert info['CFBundleShortVersionString']==info['CFBundleVersion']==module.VERSION
 build=(ROOT/'tools/build.py').read_text();assert "ROOT/'Sources/NB27Compact.m'" in build
 assert 'Maintainer: Ning\\nAuthor: Ning\\n' in build
 contents=module.archive({'usr/lib/test':(b'fixture',0o755),'Library/Preferences/entry':(b'fixture2',0o644)})
 with tarfile.open(fileobj=io.BytesIO(contents),mode='r:xz') as tar:
  members=tar.getmembers();assert all(x.uid==0 and x.gid==0 for x in members)
  assert any(x.isdir() and x.name=='./usr/lib' for x in members)
  assert tar.extractfile('./usr/lib/test').read()==b'fixture'
 member=module.ar_member('debian-binary',b'2.0\n');assert len(member)==64 and member[58:60]==b'`\n'
 print('PASS: single feature, native resource structure, seven original slots, manual-only workflow, dpkg directory/ownership fixture')
if __name__=='__main__':check()
