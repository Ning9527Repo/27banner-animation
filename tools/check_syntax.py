#!/usr/bin/env python3
"""Local syntax only, never links/signs a package or contacts CI."""
import argparse,pathlib,shutil,subprocess
ROOT=pathlib.Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--sdk',default='/var/minis/shared/sdks/iPhoneOS16.5.sdk');a=p.parse_args()
sdk=pathlib.Path(a.sdk)
if not sdk.is_dir():raise SystemExit('Missing local SDK; pass --sdk PATH')
compiler=shutil.which('clang')
if not compiler:raise SystemExit('clang is required')
for arch in ('arm64','arm64e'):
 for file in ('Sources/NB27Banner.m','Sources/NB27Compact.m','Preferences/NB27Preferences.m'):
  subprocess.run([compiler,'-target',arch+'-apple-ios15.0','-isysroot',str(sdk),
   '-fobjc-arc','-fblocks','-fsyntax-only','-Wall','-Wextra','-Werror','-Wno-unused-parameter',
   str(ROOT/file)],cwd=ROOT,check=True)
print('PASS: strict Objective-C syntax for arm64 and arm64e (not linked, not a device run)')
