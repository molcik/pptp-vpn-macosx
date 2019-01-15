//
//  AppDelegate.m
//  PPTPVPN
//
//  Created by chen on 2018/8/4.
//  Copyright © 2018年 ___CXY___. All rights reserved.
//  https://github.com/iHongRen/pptp-vpn

#import "AppDelegate.h"
#import <ServiceManagement/ServiceManagement.h>
#import <Security/Authorization.h>
#import "ITSwitch.h"
#import "PreferencesWindow.h"
#import "VPNManager.h"
#import "VPNFiler.h"

static NSString *const VPNHelperToolLabel = @"com.cxy.PPTPVPN.HelpTool";

@interface AppDelegate ()
@property (weak) IBOutlet NSMenu *vpnMenu;
@property (nonatomic, strong) NSStatusItem *vpnItem;
@property (nonatomic, strong) PreferencesWindow *preferencesWindow;

@property (weak) IBOutlet ITSwitch *connectSwitch;
@property (weak) IBOutlet NSTextField *wait;

@end

@implementation AppDelegate
{
    AuthorizationRef _authRef;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    [self helperAuth];
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
    [[VPNManager shared] disConnect:nil];
}


- (void)setupVPNItem {
    self.vpnItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    self.vpnItem.image = [NSImage imageNamed:@"vpn_disconnect"];
    self.vpnItem.menu = self.vpnMenu;


    [[VPNManager shared] connectChanged:^(VPNStatus status) {
        switch (status) {
            case VPNStatusDisConnect:
                self.vpnItem.image = [NSImage imageNamed:@"vpn_disconnect"];
                self.connectSwitch.checked = NO;
                self.connectSwitch.hidden = NO;
                self.wait.hidden = YES;                
                break;
            case VPNStatusConnecting:
                self.vpnItem.image = [NSImage imageNamed:@"vpn_disconnect"];
                self.connectSwitch.checked = NO;
                self.connectSwitch.hidden = YES;
                self.wait.hidden = NO;
                break;
            case VPNStatusConnected:
                self.vpnItem.image = [NSImage imageNamed:@"vpn_connect"];
                self.connectSwitch.checked = YES;
                self.connectSwitch.hidden = NO;
                self.wait.hidden = YES;
                break;
            default:
                break;
        }
    }];
}

- (IBAction)onConnectSwitch:(ITSwitch*)sender {
       
    if ([VPNManager shared].status == VPNStatusDisConnect) {
        [[VPNManager shared] connect:^(NSError *err) {
            if (err.code == -2) {
                [self onConfigServer: nil];
            }
        }];
    } else {
        [[VPNManager shared] disConnect:^(NSError *err) {
            
        }];
    }
}

- (IBAction)onConfigServer:(id)sender {
    if (!self.preferencesWindow) {
        self.preferencesWindow = [[PreferencesWindow alloc] initWithWindowNibName:@"PreferencesWindow"];
    }
    [[self.preferencesWindow window] orderFrontRegardless];
}

- (IBAction)openLog:(id)sender {
    [[VPNManager shared] openLog];
}

- (IBAction)onIssues:(id)sender {
    NSURL *url = [NSURL URLWithString:@"https://github.com/molcik/pptp-vpn-macosx"];
    [[NSWorkspace sharedWorkspace] openURL:url];
}

- (void)helperAuth {
    if ([self isServiceInstalled:VPNHelperToolLabel]) {
        [self setupVPNItem];
        return;
    }
    
    NSError *error = nil;
    OSStatus status = AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, &self->_authRef);
    if (status != errAuthorizationSuccess) {
        /* AuthorizationCreate really shouldn't fail. */
        assert(NO);
        self->_authRef = NULL;
    }
    
    if (![self blessHelperWithLabel:VPNHelperToolLabel error:&error]) {
        NSLog(@"Something went wrong! %@ / %d", [error domain], (int) [error code]);
    } else {
        /* At this point, the job is available. However, this is a very
         * simple sample, and there is no IPC infrastructure set up to
         * make it launch-on-demand. You would normally achieve this by
         * using XPC (via a MachServices dictionary in your launchd.plist).
         */
        NSLog(@"Job is available!");
        
        [self setupVPNItem];
    }
}

- (BOOL)blessHelperWithLabel:(NSString *)label error:(NSError **)errorPtr; {
    BOOL result = NO;
    NSError * error = nil;
    
    AuthorizationItem authItem        = { kSMRightBlessPrivilegedHelper, 0, NULL, 0 };
    AuthorizationRights authRights    = { 1, &authItem };
    AuthorizationFlags flags        =    kAuthorizationFlagDefaults                |
    kAuthorizationFlagInteractionAllowed    |
    kAuthorizationFlagPreAuthorize            |
    kAuthorizationFlagExtendRights;
    
    /* Obtain the right to install our privileged helper tool (kSMRightBlessPrivilegedHelper). */
    OSStatus status = AuthorizationCopyRights(self->_authRef, &authRights, kAuthorizationEmptyEnvironment, flags, NULL);
    if (status != errAuthorizationSuccess) {
        error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
    } else {
        CFErrorRef  cfError;
        
        /* This does all the work of verifying the helper tool against the application
         * and vice-versa. Once verification has passed, the embedded launchd.plist
         * is extracted and placed in /Library/LaunchDaemons and then loaded. The
         * executable is placed in /Library/PrivilegedHelperTools.
         */
        result = (BOOL) SMJobBless(kSMDomainSystemLaunchd, (__bridge CFStringRef)label, self->_authRef, &cfError);
        if (!result) {
            error = CFBridgingRelease(cfError);
        }
    }
    if (!result && (errorPtr != NULL) ) {
        assert(error != nil);
        *errorPtr = error;
    }
    
    return result;
}


- (BOOL)isServiceInstalled:(NSString *)label {
    CFDictionaryRef dict = SMJobCopyDictionary(kSMDomainSystemLaunchd, (__bridge CFStringRef)label);
    return dict != nil;
}

@end
