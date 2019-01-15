//
//  ServerWindowController.m
//  PPTPVPN
//
//  Created by chen on 2018/8/4.
//  Copyright © 2018年 ___CXY___. All rights reserved.
//  https://github.com/iHongRen/pptp-vpn

#import "PreferencesWindow.h"
#import "VPNManager.h"
#import "VPNFiler.h"

@interface PreferencesWindow ()

@property (weak) IBOutlet NSTextField *host;
@property (weak) IBOutlet NSTextField *username;
@property (weak) IBOutlet NSSecureTextField *password;
@property (weak) IBOutlet NSTextField *errorTip;
@property (weak) IBOutlet NSButton *mmpe;

@end

@implementation PreferencesWindow

- (void)windowDidLoad {
    [super windowDidLoad];
    
    [self.host becomeFirstResponder];
    self.host.stringValue = [VPNManager shared].host;
    self.username.stringValue = [VPNManager shared].username;
    self.password.stringValue = [VPNManager shared].password;
    self.mmpe.intValue = [VPNManager shared].mmpe;
}

- (IBAction)confirmClick:(id)sender {
    VPNManager *shared = [VPNManager shared];
    shared.host = self.host.stringValue;
    shared.username = self.username.stringValue;
    shared.password = self.password.stringValue;
    shared.mmpe = self.mmpe.intValue;
    
    [VPNFiler writeVPNFileHost:shared.host user:shared.username password:shared.password mmpe:shared.mmpe block:^(NSError *error) {
        if (error) {
            self.errorTip.hidden = NO;
            self.errorTip.stringValue = error.localizedDescription?:@"";
        } else {
            
            [shared connect:^(NSError *err) {
//                if (err) {
//                    self.errorTip.hidden = NO;
//                    self.errorTip.stringValue = err.localizedDescription;
//                } else {
//                    self.errorTip.hidden = YES;
//                    self.errorTip.stringValue = @"";
//                    [self.window performClose:self];
//                }
            }];
            [self.window performClose:self];
        }
    }];
}


@end
