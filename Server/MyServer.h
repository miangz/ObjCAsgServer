//
//  MyServer.h
//  Server
//
//  Created by miang on 5/9/2557 BE.
//  Copyright (c) 2557 miang. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MyServer : NSObject<NSStreamDelegate, NSNetServiceDelegate>
// private properties

@property (nonatomic, assign, readonly ) BOOL               isStarted;
@property (nonatomic, assign, readonly ) BOOL               isReceiving;
@property (nonatomic, strong, readwrite) NSNetService *     netService;
@property (nonatomic, assign, readwrite) CFSocketRef        listeningSocket;
@property (nonatomic, strong, readwrite) NSInputStream *    networkStream;
@property (nonatomic, strong, readwrite) NSOutputStream *   fileStream;
@property (nonatomic, copy,   readwrite) NSString *         filePath;

// forward declarations

- (void)startServer;
- (void)stopServer:(NSString *)reason;

@end