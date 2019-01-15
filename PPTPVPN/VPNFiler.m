//
//  VPNFiler.m
//  PPTPVPN
//
//  Created by chen on 2018/8/6.
//  Copyright © 2018年 ___CXY___. All rights reserved.
//  https://github.com/iHongRen/pptp-vpn

#import "VPNFiler.h"
#import "VPNManager.h"

NSString *const PPTPVPNFileDirectory = @"/etc/ppp/peers";
NSString *const PPTPVPNConfigFileName = @"pptp_vpn_config_file";
NSString *const PPTPVPNLogFile = @"/tmp/pptp_vpn_log.txt";

@implementation VPNFiler

+ (NSString*)VPNFilePath {
    return [PPTPVPNFileDirectory stringByAppendingPathComponent: PPTPVPNConfigFileName];
}



/**
 --- config ---
 remoteaddress \"vpn.ihongren.com\"\n\
 user \"ihongren\"\n\
 password \"12345678\"\n\
*/
+ (void)writeVPNFileHost:(NSString*)remoteaddress
                    user:(NSString*)user
                password:(NSString*)password
                    mmpe:(int)mmpe
                   block:(void(^)(NSError *error))complete {
    
    NSString *cmd = [NSString stringWithFormat:@"sudo mkdir -p -m=rwx %@", PPTPVPNFileDirectory];
    [[VPNManager shared] executeShellCommand:cmd block:^(NSError *err) {
        if (!err) {
            NSString *_remoteaddress = [NSString stringWithFormat:@"remoteaddress \"%@\"\n",remoteaddress?:@""];
            NSString *_user = [NSString stringWithFormat:@"user \"%@\"\n",user?:@""];
            NSString *_password = [NSString stringWithFormat:@"password \"%@\"\n",password?:@""];
            NSString *logfile = [NSString stringWithFormat:@"logfile %@\n", PPTPVPNLogFile];
            NSString *_mmpe = mmpe ? @"require-mppe-128\n" : @"" ;
            NSString *vpnConfig = [NSString stringWithFormat:@"%@%@%@%@%@",_remoteaddress,_user,_password, _mmpe, logfile];

            NSString *scriptFile = [vpnConfig stringByAppendingString:[self VPNFileOtherScript]];
        
            NSString *cmdx = [NSString stringWithFormat:@"echo \"%@\" > %@",scriptFile, [self VPNFilePath]];
            [[VPNManager shared] executeSystemShellCommand:cmdx block:complete];
        } else {
            !complete?:complete(err);
        }
    }];
}

// https://github.com/davidjosefson/lex-integrity-mac
+ (NSString*)VPNFileOtherScript {
    return
@"## Other settings\n\
plugin PPTP.ppp\n\
noauth\n\
redialcount 1\n\
redialtimer 5\n\
idle 1800\n\
mru 1436\n\
mtu 1436\n\
receive-all\n\
novj 0:0\n\
ipcp-accept-local\n\
ipcp-accept-remote\n\
hide-password\n\
looplocal\n\
nodetach\n\
ms-dns 8.8.8.8\n\
usepeerdns\n\
debug\n\
defaultroute";
}
@end
