#!/usr/bin/env python3
import pathlib,plistlib
ROOT=pathlib.Path(__file__).resolve().parents[1]
def write(path,value):
 p=ROOT/path;p.parent.mkdir(parents=True,exist_ok=True)
 p.write_bytes(plistlib.dumps(value,fmt=plistlib.FMT_XML,sort_keys=False))
write('Resources/NB27Banner.plist',{'Filter':{'Bundles':['com.apple.springboard']}})
write('Resources/entry.plist',{'entry':{'bundle':'NB27Preferences','cell':'PSLinkCell','detail':'NB27Preferences','isController':True,'label':'27banner animation','defaults':'com.ning.27banneranimation'}})
write('Resources/Info.plist',{'CFBundleIdentifier':'com.ning.27banneranimation.preferences','CFBundleName':'NB27Preferences','CFBundleExecutable':'NB27Preferences','CFBundlePackageType':'BNDL','CFBundleShortVersionString':'0.5','CFBundleVersion':'0.5','NSPrincipalClass':'NB27Preferences'})
common={'defaults':'com.ning.27banneranimation','get':'readPreferenceValue:','set':'setPreferenceValue:specifier:','PostNotification':'com.ning.27banneranimation.changed'}
items=[
 {'cell':'PSGroupCell','label':'通知横幅动画','footerText':'开启“减弱动态效果”时进出场动画回退原生；停留倍率只调整横幅自动消失计时。'},
 {'cell':'PSSwitchCell','label':'启用 iOS 27 通知动画','key':'Enabled','default':True,**common},
 {'cell':'PSGroupCell','label':'动画弹性'},
 {'cell':'PSSliderCell','label':'弹性强度','key':'Elasticity','default':1.0,'min':0.0,'max':2.0,'showValue':True,**common},
 {'cell':'PSGroupCell','label':'转场时长'},
 {'cell':'PSSliderCell','label':'时长倍率','key':'TransitionScale','default':1.0,'min':0.5,'max':2.0,'showValue':True,**common},
 {'cell':'PSGroupCell','label':'停留时长'},
 {'cell':'PSSliderCell','label':'停留倍率','key':'DwellScale','default':1.0,'min':0.5,'max':3.0,'showValue':True,**common}]
write('Resources/Root.plist',{'title':'27banner animation','items':items})
print('Generated native resources for three animation controls')
