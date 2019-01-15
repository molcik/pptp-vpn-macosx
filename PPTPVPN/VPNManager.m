//
//  VPNManager.m
//  PPTPVPN
//
//  Created by chen on 2018/8/4.
//  Copyright © 2018年 ___CXY___. All rights reserved.
//  https://github.com/iHongRen/pptp-vpn

#import "VPNManager.h"
#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>
#import <ServiceManagement/ServiceManagement.h>
#import <Security/Authorization.h>
#import <ifaddrs.h>
#import <arpa/inet.h>
#import "HelperTool.h"
#import "VPNFiler.h"

#define __SafeBlock(block, ...) (!block?:block(__VA_ARGS__))

#ifndef dispatch_block_main_async_safe
#define dispatch_block_main_async_safe(block)\
if ([NSThread isMainThread]) {\
block();\
} else {\
dispatch_async(dispatch_get_main_queue(), block);\
}
#endif

#define __SafeMainQueueBlock(block, ...)\
dispatch_block_main_async_safe(^{\
    __SafeBlock(block, __VA_ARGS__);\
});

@interface VPNManager()

@property (atomic, strong, readwrite) NSXPCConnection *helperToolConnection;
@property (nonatomic, copy) VPNConnectChangedBlock connectChangedBlock;
@end

@implementation VPNManager

+ (instancetype)shared {
    static VPNManager *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] init];
        [shared getConfig];        
    });
    return shared;
}

- (void)getConfig {
    self.host = [[NSUserDefaults standardUserDefaults] objectForKey:@"pptp.vpn.host"]?:@"";
    self.username = [[NSUserDefaults standardUserDefaults] objectForKey:@"pptp.vpn.username"]?:@"";
    
    NSString *storedPassword = [[NSUserDefaults standardUserDefaults] objectForKey:@"pptp.vpn.password"]?:@"";
    self.password = storedPassword.length ? [storedPassword substringFromIndex:1] : @"";
    NSNumber *storedMmpe = [[NSUserDefaults standardUserDefaults] objectForKey:@"pptp.vpn.mmpe"]?:[NSNumber numberWithInt:1];
    self.mmpe = storedMmpe.intValue;
    
    self.status = VPNStatusDisConnect;
}

- (void)setHost:(NSString *)host {
    _host = host;
    [[NSUserDefaults standardUserDefaults] setObject:host forKey:@"pptp.vpn.host"];
}

- (void)setUsername:(NSString *)username {
    _username = username;
    [[NSUserDefaults standardUserDefaults] setObject:username forKey:@"pptp.vpn.username"];
}

- (void)setPassword:(NSString *)password {
    _password = password;
    NSString *storePassword = [NSString stringWithFormat:@"a%@",password?:@""];
    [[NSUserDefaults standardUserDefaults] setObject:storePassword forKey:@"pptp.vpn.password"];
}

- (void)setMmpe:(int)mmpe {
    _mmpe = mmpe;
    NSNumber *storeMmpe = [NSNumber numberWithInt: mmpe];
    [[NSUserDefaults standardUserDefaults] setObject:storeMmpe forKey:@"pptp.vpn.mmpe"];
}

- (void)setStatus:(VPNStatus)status {
    _status = status;
    __SafeMainQueueBlock(self.connectChangedBlock, status);
}

- (void)connect:(VPNConnectBlock)block {
    if (![[NSFileManager defaultManager] fileExistsAtPath:[VPNFiler VPNFilePath]]) {
        NSError *err = [NSError errorWithDomain:NSPOSIXErrorDomain
                                           code:-2
                                       userInfo:@{NSLocalizedDescriptionKey: @"Check you VPN details"}];
        self.status = VPNStatusDisConnect;
        __SafeMainQueueBlock(block, err);
        return;
    }    
    
    self.status = VPNStatusConnecting;
    [self deleteLog:^(NSError *delErr) {
        if (self.status == VPNStatusConnected) {
            [self disConnect:nil];
        }
        
        NSString *cmd = [NSString stringWithFormat:@"sudo pppd call %@ &" ,PPTPVPNConfigFileName];
        [self executeSystemShellCommand:cmd block:^(NSError *err) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self checkIsConnenctedTryTimes:5 block:^(BOOL isConnected) {
                    NSLog(@"-----------isConnected: %@",@(isConnected));
                    if (isConnected) {
                        __SafeMainQueueBlock(block, nil);
                        self.status = VPNStatusConnected;
                    } else {
                        [self logErrorIfExist:err];
                        self.status = VPNStatusDisConnect;
                        __SafeMainQueueBlock(block, err);
                    }
                }];
            });
        }];
    }];
}

- (void)disConnect:(VPNConnectBlock)block {
    self.status = VPNStatusConnecting;
    [self executeShellCommand:@"sudo killall pppd com.cxy.PPTPVPN.HelpTool" block:^(NSError *err) {
        self.status = VPNStatusDisConnect;
        __SafeMainQueueBlock(block, err);
    }];
}

- (void)connectChanged:(VPNConnectChangedBlock)block {
    self.connectChangedBlock = block;
}

- (void)openLog {
    NSString *cmd = [NSString stringWithFormat:@"open %@" ,PPTPVPNLogFile];
    NSString *script = [NSString stringWithFormat:@"do shell script \"%@\"",cmd];
    NSAppleScript *appleScript = [[NSAppleScript alloc] initWithSource:script];
    [appleScript executeAndReturnError:nil];
    //    [self executeShellCommand:cmd block:nil];
}

- (void)deleteLog:(VPNConnectBlock)block {
    NSString *cmd = [NSString stringWithFormat:@"rm -f %@" ,PPTPVPNLogFile];
    [self executeShellCommand:cmd block:block];
}

//已使用logfile命令， 这个方法暂时没有用到
- (void)writeLog:(NSString*)log {
    NSString *cmd = [NSString stringWithFormat:@"echo \"%@\" >> %@",log,PPTPVPNLogFile];
    [self executeShellCommand:cmd block:nil];
}

- (void)readLog:(void(^)(NSString* ))block {
    NSString *cmd = [NSString stringWithFormat:@"cat %@",PPTPVPNLogFile];
    [self executeShellPath:@"/bin/bash" arguments:@[@"-c", cmd] block:^(NSError *err, NSString *output) {
        __SafeMainQueueBlock(block, output);
    }];
}

- (void)checkIsConnenctedTryTimes:(NSInteger)times block:(void(^)(BOOL connected))block {
    [self readLog:^(NSString *output){
        NSLog(@"-----------output--------------");
        BOOL isConnected = [output containsString:@"pptp_wait_input: Address added"];
        if (isConnected) {
            __SafeMainQueueBlock(block, YES);
        } else {
            if (times) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self checkIsConnenctedTryTimes:times-1 block:block];
                });
            } else {
                __SafeMainQueueBlock(block, NO);
            }
        }
    }];
}

- (void)executeSystemShellCommand:(NSString*)cmd block:(VPNConnectBlock)block {
    [self connectAndexecuteCommandBlock:^(NSError *err) {
        if (err) {
            __SafeMainQueueBlock(block, err);
        } else {
            [[self.helperToolConnection remoteObjectProxyWithErrorHandler:^(NSError * _Nonnull error) {
                if (error) {
                    __SafeMainQueueBlock(block, error);
                }
            }] executeShellSystemCommand:cmd withReply:^(NSInteger reply) {
                NSLog(@"-----------reply: %@",@(reply));
                if (reply == 0) {
                    __SafeMainQueueBlock(block, nil);
                } else {
                    NSError *erro = [self createError:[NSString stringWithFormat:@"%@Run failed",cmd]];
                    __SafeMainQueueBlock(block, erro);
                }
            }];
        }
    }];
}


- (void)executeShellCommand:(NSString*)cmd block:(VPNConnectBlock)block {
    [self connectAndexecuteCommandBlock:^(NSError *err) {
        if (err) {
            NSLog(@"%@",err);
            [self logErrorIfExist:err];
            __SafeMainQueueBlock(block, err);
        } else {
            [[self.helperToolConnection remoteObjectProxyWithErrorHandler:^(NSError * _Nonnull error) {
                if (error) {
                    NSLog(@"%@",error);
                    [self logErrorIfExist:error];
                    __SafeMainQueueBlock(block, error);
                }
            }] executeShellCommand:cmd withReply:^(NSDictionary *errorInfo) {
                NSError *erro = nil;
                if (errorInfo) {
                    NSLog(@"%@",errorInfo);
                    erro = [self createError:[NSString stringWithFormat:@"%@Run failed",cmd]];
                    [self logErrorIfExist:erro];
                }
                __SafeMainQueueBlock(block, erro);
            }];
        }
    }];
}

- (void)executeShellPath:(NSString*)path arguments:(NSArray*)args block:(void(^)(NSError *error, NSString *output))block {
    [self connectAndexecuteCommandBlock:^(NSError *err) {
        if (err) {
            [self logErrorIfExist:err];
            __SafeMainQueueBlock(block, err, nil);
        } else {
            [[self.helperToolConnection remoteObjectProxyWithErrorHandler:^(NSError * _Nonnull errorx) {
                if (errorx) {
                    NSLog(@"output: %@", errorx);
                    [self logErrorIfExist:errorx];
                    __SafeMainQueueBlock(block, errorx, nil);
                }
            }] executeShellPath:path arguments:args withReply:^(NSError *errorInfo, NSString *outputString) {
                NSLog(@"output: %@", outputString);
                [self logErrorIfExist:errorInfo];
                __SafeMainQueueBlock(block, errorInfo, outputString);
            }];
        }
    }];
}

- (void)connectToHelperTool
// Ensures that we're connected to our helper tool.
{
    assert([NSThread isMainThread]);
    if (self.helperToolConnection == nil) {
        self.helperToolConnection = [[NSXPCConnection alloc] initWithMachServiceName:@"com.cxy.PPTPVPN.HelpTool" options:NSXPCConnectionPrivileged];
        self.helperToolConnection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(HelperToolProtocol)];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
        // We can ignore the retain cycle warning because a) the retain taken by the
        // invalidation handler block is released by us setting it to nil when the block
        // actually runs, and b) the retain taken by the block passed to -addOperationWithBlock:
        // will be released when that operation completes and the operation itself is deallocated
        // (notably self does not have a reference to the NSBlockOperation).
        self.helperToolConnection.invalidationHandler = ^{
            // If the connection gets invalidated then, on the main thread, nil out our
            // reference to it.  This ensures that we attempt to rebuild it the next time around.
            self.helperToolConnection.invalidationHandler = nil;
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                self.helperToolConnection = nil;
                NSLog(@"connection invalidated\n");
            }];
        };
#pragma clang diagnostic pop
        [self.helperToolConnection resume];
    }

}

- (void)connectAndexecuteCommandBlock:(void(^)(NSError *))commandBlock
// Connects to the helper tool and then executes the supplied command block on the
// main thread, passing it an error indicating if the connection was successful.
{
    assert([NSThread isMainThread]);
    
    // Ensure that there's a helper tool connection in place.
    
    [self connectToHelperTool];
    
    // Run the command block.  Note that we never error in this case because, if there is
    // an error connecting to the helper tool, it will be delivered to the error handler
    // passed to -remoteObjectProxyWithErrorHandler:.  However, I maintain the possibility
    // of an error here to allow for future expansion.
    
    commandBlock(nil);
}

- (void)logErrorIfExist:(NSError *)error
// Logs the error to the text view.
{
    // any thread
//    assert(error != nil);
    if ([error isKindOfClass:[NSError class]]) {
        NSLog(@"error: %@ /  %@ / %@\n", error.localizedDescription, [error domain], @([error code]));
    }
}

- (NSError*)createError:(NSString*)errText {
    return [NSError errorWithDomain:NSPOSIXErrorDomain
                               code:-1
                           userInfo:@{NSLocalizedDescriptionKey: errText}];
}
@end
