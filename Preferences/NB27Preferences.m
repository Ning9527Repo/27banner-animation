#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <notify.h>
// Publicly visible Objective-C selectors of Apple's private Preferences host.
// Resolution occurs in Settings; no copied framework or original prefs binary.
@interface PSSpecifier:NSObject
-(id)propertyForKey:(NSString *)key;
@end
@interface PSListController:UIViewController
-(NSArray *)loadSpecifiersFromPlistName:(NSString *)name target:(id)target bundle:(NSBundle *)bundle;
-(void)setSpecifiers:(NSArray *)specifiers;
@end
@interface NB27Preferences:PSListController
@property(nonatomic,strong) NSArray *nb27Items;
@end
@implementation NB27Preferences
-(NSArray *)specifiers {
 if(!self.nb27Items) {
  NSArray *loaded=[self loadSpecifiersFromPlistName:@"Root" target:self bundle:[NSBundle bundleForClass:self.class]];
  self.nb27Items=loaded?:@[];[super setSpecifiers:self.nb27Items];
 }
 return self.nb27Items;
}
-(id)readPreferenceValue:(PSSpecifier *)specifier {
 NSString *key=[specifier propertyForKey:@"key"];
 if(!key)return nil;
 id value=CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)key,CFSTR("com.ning.27banneranimation")));
 return value?:[specifier propertyForKey:@"default"];
}
-(void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
 NSString *key=[specifier propertyForKey:@"key"];if(!key)return;
 CFPreferencesSetAppValue((__bridge CFStringRef)key,(__bridge CFPropertyListRef)value,CFSTR("com.ning.27banneranimation"));
 CFPreferencesAppSynchronize(CFSTR("com.ning.27banneranimation"));
 notify_post("com.ning.27banneranimation.changed");
}
@end
