#!/usr/bin/env python3
import pathlib,plistlib
ROOT=pathlib.Path(__file__).resolve().parents[1]
def write(path,value):
 p=ROOT/path;p.parent.mkdir(parents=True,exist_ok=True)
 p.write_bytes(plistlib.dumps(value,fmt=plistlib.FMT_XML,sort_keys=False))
write('Resources/NB27Banner.plist',{'Filter':{'Bundles':['com.apple.springboard']}})
write('Resources/entry.plist',{'entry':{
 'bundle':'NB27Preferences','cell':'PSLinkCell','detail':'NB27Preferences',
 'isController':True,'label':'27banner animation','defaults':'com.ning.27banneranimation'}})
write('Resources/Info.plist',{
 'CFBundleIdentifier':'com.ning.27banneranimation.preferences','CFBundleName':'NB27Preferences',
 'CFBundleExecutable':'NB27Preferences','CFBundlePackageType':'BNDL',
 'CFBundleShortVersionString':'0.2','CFBundleVersion':'0.2','NSPrincipalClass':'NB27Preferences'})
write('Resources/Root.plist',{'title':'27banner animation','items':[
 {'cell':'PSGroupCell','label':'通知横幅动画',
  'footerText':'iOS 27 横幅进出场动画。开启“减弱动态效果”时回退原生动画。'},
 {'cell':'PSSwitchCell','label':'启用 iOS 27 通知动画','key':'Enabled','default':True,
  'defaults':'com.ning.27banneranimation','get':'readPreferenceValue:',
  'set':'setPreferenceValue:specifier:','PostNotification':'com.ning.27banneranimation.changed'}]})
print('Generated four native plist resources')
