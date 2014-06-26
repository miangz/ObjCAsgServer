//
//  AppDelegate.m
//  Server
//
//  Created by miang on 5/2/2557 BE.
//  Copyright (c) 2557 miang. All rights reserved.
//

#import "AppDelegate.h"
#import "ldapTest.h"
#import "TCPServer.h"

@implementation AppDelegate
{
    TCPServer *server;
    char                _networkOperationCountDummy;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    server = [[TCPServer alloc]init];
    [server startServer];
    [server startUpdateStock];
//    myServer = [[Server alloc]init];
//    myServer.stopServer = YES;
//    [[NetworkManager sharedInstance] addObserver:self forKeyPath:@"networkOperationCount" options:NSKeyValueObservingOptionInitial context:&self->_networkOperationCountDummy];
    
}

@end
