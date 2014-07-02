//
//  TCPServer.m
//  Server
//
//  Created by miang on 5/12/2557 BE.
//  Copyright (c) 2557 miang. All rights reserved.
//

#import "TCPServer.h"
#import "NetworkManager.h"
#include <CFNetwork/CFNetwork.h>
#import "QNetworkAdditions.h"

#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>
 
@implementation TCPServer{
    NSTimer *timerCheckConnection;
    LdapManager *myManager;
    UpdatingStock *update;
}

@synthesize netService      = _netService;
@synthesize networkStream   = _networkStream;
@synthesize listeningSocket = _listeningSocket;
@synthesize fileStream      = _fileStream;

@synthesize bufferOffset  = _bufferOffset;
@synthesize bufferLimit   = _bufferLimit;

+ (id)sharedManager {
    static TCPServer *sharedMyManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedMyManager = [[self alloc] init];
    });
    return sharedMyManager;
}

- (void)startUpdateStock{
    update = [UpdatingStock new];
    myManager = [LdapManager new];
    [update startUpdateStock];
}
#pragma mark * Status management
- (void)sendDidStart
{
    NSLog( @"Sending" );
    [[NetworkManager sharedInstance] didStartNetworkOperation];
}
- (void)serverDidStartOnPort:(NSUInteger)port
{
    assert( (port != 0) && (port < 65536) );
    NSString *s = [NSString stringWithFormat:@"Started on port %zu", (size_t) port];
    NSLog(@"%@",s);
}

- (void)serverDidStopWithReason:(NSString *)reason
{
    if (reason == nil) {
        reason = @"Stopped";
    }
    NSLog(@"%@",reason);
}
- (void)receiveDidStart
{
    NSLog( @"Receiving" );
    [[NetworkManager sharedInstance] didStartNetworkOperation];
}

- (void)updateStatus:(NSString *)statusString
{
    assert(statusString != nil);
    NSLog(@"%@", statusString);
}

- (void)receiveDidStopWithStatus:(NSString *)statusString
{
    if (statusString == nil) {
        statusString = @"Receive succeeded";
    }
    [[NetworkManager sharedInstance] didStopNetworkOperation];
}

- (void)sendDidStopWithStatus:(NSString *)statusString
{
    if (statusString == nil) {
        statusString = @"Send succeeded";
    }
    [[NetworkManager sharedInstance] didStopNetworkOperation];
}
#pragma mark * Core transfer code

// This is the code that actually does the networking.

- (BOOL)isStarted
{
    return (self.netService != nil);
}

- (BOOL)isReceiving
{
    return (self.networkStream != nil);
}

- (BOOL)isSending
{
    return (self.networkStream != nil);
}

- (void)startReceive:(int)fd
{
    CFReadStreamRef     readStream;
    
    assert(fd >= 0);
    
    
    CFStreamCreatePairWithSocket(NULL, fd, &readStream, NULL);
    
    self.networkStream = (__bridge NSInputStream *) readStream;
    CFRelease(readStream);
    
    [self.networkStream setProperty:(id)kCFBooleanTrue forKey:(NSString *)kCFStreamPropertyShouldCloseNativeSocket];
    
    self.networkStream.delegate = self;
    [self.networkStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [self.networkStream open];
    [self receiveDidStart];
}

- (void)stopReceiveWithStatus:(NSString *)statusString
{
    if (self.networkStream != nil) {
        self.networkStream.delegate = nil;
        [self.networkStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [self.networkStream close];
    }
    if (self.fileStream != nil) {
        [self.fileStream close];
        self.fileStream = nil;
    }
    [self receiveDidStopWithStatus:statusString];
}
- (void)acceptConnection:(int)fd
{
    [self startReceive:fd];
}

static void AcceptCallback(CFSocketRef s, CFSocketCallBackType type, CFDataRef address, const void *data, void *info)
// Called by CFSocket when someone connects to our listening socket.
// This implementation just bounces the request up to Objective-C.
{
    NSLog(@"AcceptCallback");
    
    TCPServer *  obj;
    
#pragma unused(type)
    assert(type == kCFSocketAcceptCallBack);
#pragma unused(address)
    // assert(address == NULL);
    assert(data != NULL);
    
    obj = (__bridge TCPServer *) info;
    assert(obj != nil);
    
    assert(s == obj->_listeningSocket);
#pragma unused(s)
    
    [obj acceptConnection:*(int *)data];
}

- (void)netService:(NSNetService *)sender didNotPublish:(NSDictionary *)errorDict
{
#pragma unused(sender)
    assert(sender == self.netService);
#pragma unused(errorDict)
    
    [self stopServer:@"Registration failed"];
}

- (void)startServer
{
    BOOL                success;
    int                 err;
    int                 fd;
    int                 junk;
    struct sockaddr_in  addr;
    NSUInteger          port;
    
    // Create a listening socket and use CFSocket to integrate it into our
    // runloop.  We bind to port 0, which causes the kernel to give us
    // any free port, then use getsockname to find out what port number we
    // actually got.
    
    port = 0;
    
    fd = socket(AF_INET, SOCK_STREAM, 0);
    success = (fd != -1);
    
    if (success) {
        memset(&addr, 0, sizeof(addr));
        addr.sin_len    = sizeof(addr);
        addr.sin_family = AF_INET;
        addr.sin_port   = 0;
        addr.sin_addr.s_addr = INADDR_ANY;
        err = bind(fd, (const struct sockaddr *) &addr, sizeof(addr));
        success = (err == 0);
    }
    if (success) {
        err = listen(fd, 5);
        success = (err == 0);
    }
    if (success) {
        socklen_t   addrLen;
        
        addrLen = sizeof(addr);
        err = getsockname(fd, (struct sockaddr *) &addr, &addrLen);
        success = (err == 0);
        
        if (success) {
            assert(addrLen == sizeof(addr));
            port = ntohs(addr.sin_port);
        }
    }
    if (success) {
        CFSocketContext context = { 0, (__bridge void *) self, NULL, NULL, NULL };
        
        assert(self->_listeningSocket == NULL);
        self->_listeningSocket = CFSocketCreateWithNative(
                                                          NULL,
                                                          fd,
                                                          kCFSocketAcceptCallBack,
                                                          AcceptCallback,
                                                          &context
                                                          );
        success = (self->_listeningSocket != NULL);
        
        if (success) {
            CFRunLoopSourceRef  rls;
            
            fd = -1;        // listeningSocket is now responsible for closing fd
            
            rls = CFSocketCreateRunLoopSource(NULL, self.listeningSocket, 0);
            assert(rls != NULL);
            
            CFRunLoopAddSource(CFRunLoopGetCurrent(), rls, kCFRunLoopDefaultMode);
            
            CFRelease(rls);
        }
    }
    
    // Now register our service with Bonjour.  See the comments in -netService:didNotPublish:
    // for more info about this simplifying assumption.
    
    if (success) {
        self.netService = [[NSNetService alloc] initWithDomain:@"local." type:@"_x-SNSUpload._tcp." name:@"Test" port:port];
        success = (self.netService != nil);
    }
    if (success) {
        self.netService.delegate = self;
        
        [self.netService publishWithOptions:NSNetServiceNoAutoRename];
        
        // continues in -netServiceDidPublish: or -netService:didNotPublish: ...
    }
    
    // Clean up after failure.
    
    if ( success ) {
        assert(port != 0);
        [self serverDidStartOnPort:port];
    } else {
        [self stopServer:@"Start failed"];
        if (fd != -1) {
            junk = close(fd);
            assert(junk == 0);
        }
    }
}

- (void)stopServer:(NSString *)reason
{
    if (self.isReceiving) {
        [self stopReceiveWithStatus:@"Cancelled"];
    }
    if (self.netService != nil) {
        [self.netService stop];
        self.netService = nil;
    }
    if (self.listeningSocket != NULL) {
        CFSocketInvalidate(self.listeningSocket);
        CFRelease(self->_listeningSocket);
        self->_listeningSocket = NULL;
    }
    [self serverDidStopWithReason:reason];
}
#pragma mark handleEvent
- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode
{
    switch (eventCode) {
        case NSStreamEventOpenCompleted: {
            [self updateStatus:@"Opened connection"];
//            haveToAnswer = YES;
            [timerCheckConnection invalidate];
            timerCheckConnection = nil;
            timerCheckConnection = [NSTimer scheduledTimerWithTimeInterval:8 target:self selector:@selector(askForRepeat) userInfo:nil repeats:NO];
        } break;
        case NSStreamEventHasBytesAvailable: {
//            haveToAnswer = NO;
            if (aStream == self.networkStream) {
                
//                haveToAnswer = YES;
                [timerCheckConnection invalidate];
                timerCheckConnection = nil;
                timerCheckConnection = [NSTimer scheduledTimerWithTimeInterval:8 target:self selector:@selector(askForRepeat) userInfo:nil repeats:NO];
                
                uint8_t buffer[5000];
                long len;
                NSMutableData *data = [[NSMutableData alloc]init];
                while ([self.networkStream hasBytesAvailable]) {
                    len = [self.networkStream read:buffer maxLength:sizeof(buffer)];
                    if (len > 0) {
                        
                        NSString *output = [[NSString alloc] initWithBytes:buffer length:len encoding:NSASCIIStringEncoding];
                        NSData *d = [[NSData alloc]initWithBytes:buffer length:len];
                        if (output != nil ) {
                            [data appendData:d];
                        }
                    }else{
                        return;
                    }
                }
                NSString * message = [[NSString alloc]initWithData:data encoding:NSASCIIStringEncoding];
                
                if ([message rangeOfString:@":"].location == NSNotFound) {
                    NSLog(@"not contain : in message -%@-",message);
                    return;
                }
                NSArray *separate = [message componentsSeparatedByString:@":"];
                if ([separate count]<1) {
                    NSLog(@"can't separate");
                    [self sendMessage:@"Wrong format!!!!!!\n"];
                    return;
                }
                NSString *stockName = [separate objectAtIndex:0];
                myManager.stockList = nil;
                myManager.stockList = [[NSMutableArray alloc]initWithArray:update.stockList];
                if ([stockName isEqualToString:@"createAnAccount"]) {
                    [myManager createAnAccount:message];
                    return;
                }
                else if ([stockName isEqualToString:@"signIn"]){
                    [myManager signIn:message];
                    return;
                }
                else if ([stockName isEqualToString:@"modifyStock"]){
                    [myManager modifyStock:separate];
                    return;
                }else if ([stockName isEqualToString:@"getStockInfoOfUid"]){
                    [myManager getStockInfoOfUid:separate];
                    return;
                }else if([stockName isEqualToString:@"removeStock"]){
                    [myManager removeStock:separate];
                    
                }else if ([stockName isEqualToString:@"moveStock"]){
                    [myManager moveStock:separate];
                }else if([stockName isEqualToString:@"removeList"]){
                    [myManager removeList:separate];
                    
                }else if ([stockName isEqualToString:@"reorderList"]){
                    [myManager reorderList:separate];
                }else if ([stockName isEqualToString:@"getTheseStock"]){
                    [myManager getTheseStock:separate];
                }else if ([stockName isEqualToString:@"getStockDetail"]){
                    [myManager getStockDetail:[separate objectAtIndex:1]];
                }else if([stockName isEqualToString:@"getAllStockList"]){
                    [myManager getAllStockList:separate];
                }else{
                    NSLog(@"%@",stockName);
                    NSString *s = [separate objectAtIndex:1];
                    NSString *str;
                    if ([s isEqualToString:@"full"]) {
                        NSLog(@"FULL");
                        str =[NSString stringWithFormat:@"http://download.finance.yahoo.com/d/quotes.csv?s=%@&f=snl1c1p2vp0o0m0w0m3&e=.csv",stockName];
                    }else if ([s isEqualToString:@"some"]) {
                        NSLog(@"SOME");
                        str = [NSString stringWithFormat:@"http://download.finance.yahoo.com/d/quotes.csv?s=%@&f=snl1c1p2v&e=.csv",stockName];
                    }else if ([s isEqualToString:@"graph"]){
                        NSLog(@"SOME");
                        NSCalendar *cal = [NSCalendar currentCalendar];
                        NSDateComponents *components = [cal components:(  NSDayCalendarUnit | NSMonthCalendarUnit) fromDate:[NSDate date]];
                        int end = (int)[components day];
                        [components setMonth:([components month] - 1)];
                        int start = (int)[components day];
                        str = [NSString stringWithFormat:@"http://ichart.finance.yahoo.com/table.csv?s=%@&a=02&b=%d&c=2014&d=03&e=%d&f=2014&g=d&ignore=.csv",stockName,start,end];
                    }
                    
                    NSURL *url = [NSURL URLWithString:str];
                    NSMutableString *reply = [NSMutableString stringWithContentsOfURL:url encoding:NSASCIIStringEncoding error:nil];
                    NSArray *result = [reply componentsSeparatedByString:@","];
                    NSLog(@"result :%@",result);
                    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:result];
                    NSLog(@"data[%lu] :%@ ",(unsigned long)data.length,data);
                    
                    [self.fileStream write:[data bytes] maxLength:[data length]];
                }
                NSLog(@"I said ...");
                
            }
        } break;
        case NSStreamEventHasSpaceAvailable: {
            ;   // should never happen for the output stream
        } break;
        case NSStreamEventErrorOccurred: {
            [self stopReceiveWithStatus:@"Stream open error"];
        } break;
        case NSStreamEventEndEncountered: {
            // ignore
        } break;
        default: {;
        } break;
    }
    
}

#pragma mark sending

#pragma mark - NSStreamDelegate
- (void)sendMessage:(NSString *)string{
    
    
    if ([self.fileStream streamStatus]==NSStreamStatusOpen) {
        [self.fileStream close];
        [self.networkStream close];
    }
    
    [self initNetworkCommunication];
    
    //    NSString *s = [[NSString alloc]initWithFormat:@"%@\n",string];
    NSLog(@"I said: %@\n" , string);
	NSData *data = [[NSData alloc] initWithData:[string dataUsingEncoding:NSASCIIStringEncoding]];
	[self.fileStream write:[data bytes] maxLength:[data length]];
    
}

-(void)askForRepeat{
    [self sendMessage:@"Please repeat your request again!!!\n"];
}

- (void)sendData:(NSData *)data{
    
    
    if ([self.fileStream streamStatus]==NSStreamStatusOpen) {
        [self.fileStream close];
        [self.networkStream close];
    }
    
    [self initNetworkCommunication];
    
	[self.fileStream write:[data bytes] maxLength:[data length]];
    
}
- (void) initNetworkCommunication {
    NSOutputStream *    output;
    BOOL                success;
    NSNetService *      netService;
    
    netService = [[NSNetService alloc] initWithDomain:@"local." type:@"_x-SNSDownload._tcp." name:@"Test"];
    assert(netService != nil);
    
    [netService qNetworkAdditions_getInputStream:NULL outputStream:&output];
    
    self.fileStream = output;
    self.fileStream.delegate = self;
    [self.fileStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    
    [self.fileStream open];
    // Tell the UI we're sending.
    
    [self sendDidStart];
    
}


- (void)stopSendWithStatus:(NSString *)statusString
{
    if (self.fileStream != nil) {
        self.fileStream.delegate = nil;
        [self.fileStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [self.fileStream close];
        self.fileStream = nil;
    }
    if (self.networkStream != nil) {
        [self.networkStream close];
        self.networkStream = nil;
    }
    self.bufferOffset = 0;
    self.bufferLimit  = 0;
    [self sendDidStopWithStatus:statusString];
}

@end
