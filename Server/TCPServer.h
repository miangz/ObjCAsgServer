//
//  TCPServer.h
//  Server
//
//  Created by miang on 5/12/2557 BE.
//  Copyright (c) 2557 miang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NSMutableArray+MoveIndex.h"
#import "UpdatingStock.h"
#import "LdapManager.h"

@interface TCPServer : NSObject <NSStreamDelegate, NSNetServiceDelegate>

@property (nonatomic, assign, readonly ) BOOL               isStarted;
@property (nonatomic, assign, readonly ) BOOL               isReceiving;
@property (nonatomic, strong, readwrite) NSNetService *     netService;
@property (nonatomic, assign, readwrite) CFSocketRef        listeningSocket;
@property (nonatomic, strong, readwrite) NSInputStream *    networkStream;
@property (nonatomic, strong, readwrite) NSOutputStream *   fileStream;

@property (nonatomic, assign, readonly ) BOOL               isSending;
@property (nonatomic, assign, readwrite) size_t             bufferOffset;
@property (nonatomic, assign, readwrite) size_t             bufferLimit;

+ (id)sharedManager;
- (void)startUpdateStock;
- (void)startServer;
- (void)sendMessage:(NSString *)string;
- (void)sendData:(NSData *)data;
@end
