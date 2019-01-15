//
//  VPNManager.h
//  PPTPVPN
//
//  Created by chen on 2018/8/4.
//  Copyright © 2018年 ___CXY___. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, VPNStatus) {
    VPNStatusDisConnect,
    VPNStatusConnecting,
    VPNStatusConnected
};


typedef void (^VPNConnectBlock)(NSError *err);
typedef void (^VPNConnectChangedBlock)(VPNStatus status);

@interface VPNManager : NSObject
@property (nonatomic, copy) NSString *host;
@property (nonatomic, copy) NSString *username;
@property (nonatomic, copy) NSString *password;
@property (nonatomic) int mmpe;

@property (nonatomic, assign) VPNStatus status;
+ (instancetype)shared;


- (void)connect:(VPNConnectBlock)block;
- (void)disConnect:(VPNConnectBlock)block;

- (void)connectChanged:(VPNConnectChangedBlock)block;
- (void)openLog;

- (void)executeShellCommand:(NSString*)cmd block:(VPNConnectBlock)block;
- (void)executeSystemShellCommand:(NSString*)cmd block:(VPNConnectBlock)block;
@end
