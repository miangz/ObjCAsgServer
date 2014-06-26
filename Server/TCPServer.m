//
//  TCPServer.m
//  Server
//
//  Created by miang on 5/12/2557 BE.
//  Copyright (c) 2557 miang. All rights reserved.
//

#import "TCPServer.h"
#import "ldapTest.h"
#import "NetworkManager.h"
#include <CFNetwork/CFNetwork.h>
#import "QNetworkAdditions.h"

#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>
 
@implementation TCPServer{
    NSMutableArray *stockList;
    NSArray *currentList;
//    BOOL haveToAnswer;
    NSTimer *timerCheckConnection;
}

@synthesize netService      = _netService;
@synthesize networkStream   = _networkStream;
@synthesize listeningSocket = _listeningSocket;
@synthesize fileStream      = _fileStream;


@synthesize bufferOffset  = _bufferOffset;
@synthesize bufferLimit   = _bufferLimit;

- (void)startUpdateStock{
    NSLog(@"updating");
    
//    haveToAnswer = NO;
    stockList = [[NSMutableArray alloc]initWithArray:[[NSUserDefaults standardUserDefaults]objectForKey:@"stockArray"]];
    
    float change = (((float)rand() / RAND_MAX) * 2);
    [NSTimer scheduledTimerWithTimeInterval:change target:self
                                   selector:@selector(updateStock) userInfo:nil repeats:NO];
}
-(void) updateStock{
    for (int i = 0; i<stockList.count; i++) {
        float change = (((float)rand() / RAND_MAX) * 20)-10;
        NSString *s = [[stockList objectAtIndex:i]objectAtIndex:2];
        float value = [s floatValue];
        value = value * (1+(change/100));
        if (value == 0) {
            value = (((float)rand() / RAND_MAX) * 2);
        }
//        //
        if (value < 5) {
            value += 10;
        }else if (value > 1000){
            value /= 10;
        }
        //
        NSMutableArray *a = [[NSMutableArray alloc]initWithArray:[stockList objectAtIndex:i]];
        //value
        [a replaceObjectAtIndex:2 withObject:[NSString stringWithFormat:@"%.2f", value]];
        //change
        [a replaceObjectAtIndex:3 withObject:[NSString stringWithFormat:@"%.2f",value * change/100]];
        //percent change
        [a replaceObjectAtIndex:4 withObject:[NSString stringWithFormat:@"%.2f", change]];
        [stockList replaceObjectAtIndex:i withObject:a];
    }
    
    [[NSUserDefaults standardUserDefaults]setObject:stockList forKey:@"stockArray"];
    [[NSUserDefaults standardUserDefaults]synchronize];
    
    [NSTimer scheduledTimerWithTimeInterval:2.0 target:self
                                   selector:@selector(updateStock) userInfo:nil repeats:NO];
    
    
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
//    if (haveToAnswer == NO) {
//        return;
//    }
    [self sendMessage:@"Please repeat your request again!!!\n"];
//    haveToAnswer = NO;
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
                
                if ([stockName isEqualToString:@"createAnAccount"]) {
                    [self createAnAccount:message];
                    return;
                }
                else if ([stockName isEqualToString:@"signIn"]){
                    [self signIn:message];
                    return;
                }
                else if ([stockName isEqualToString:@"modifyStock"]){
                    [self modifyStock:separate];
                    return;
                }else if ([stockName isEqualToString:@"getStockInfoOfUid"]){
                    currentList = nil;
                    currentList = [[NSArray alloc]initWithArray:separate];
                    [self getStockInfoOfUid:separate];
                    return;
                }else if([stockName isEqualToString:@"removeStock"]){
                    [self removeStock:separate];
                    
                }else if ([stockName isEqualToString:@"moveStock"]){
                    [self moveStock:separate];
                }else if([stockName isEqualToString:@"removeList"]){
                    [self removeList:separate];
                    
                }else if ([stockName isEqualToString:@"reorderList"]){
                    [self reorderList:separate];
                }else if ([stockName isEqualToString:@"getTheseStock"]){
                    [self getTheseStock:separate];
                }else if ([stockName isEqualToString:@"getStockDetail"]){
                    [self getStockDetail:[separate objectAtIndex:1]];
                }else if([stockName isEqualToString:@"getAllStockList"]){
                    [self getAllStockList:separate];
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

-(void)createAnAccount:(NSString *)message{
    NSArray *separateType = [message componentsSeparatedByString:@"\t"];
    if (separateType.count<4) {
        NSLog(@"ERROR : can't separate to create an account");
        return;
    }
    
    ldapTest *l = [[ldapTest alloc]init];
    NSLog(@"uid : %@",[separateType objectAtIndex:2]);
    const char *const_uid=[[separateType objectAtIndex:2] UTF8String];
    char *uid = calloc([[separateType objectAtIndex:2] length]+1, 1);
    strncpy(uid, const_uid, [[separateType objectAtIndex:2]  length]);
    
    char *j = [l retrieveEntry:uid];
    NSString *result = [NSString stringWithCString:j encoding:NSUTF8StringEncoding];
    NSLog(@"result : %@",result);
    if ([result isEqualToString:@"1"]||![result isEqualToString:@"0"]) {
        NSLog(@"Someone already has that username. Try another!\n");
        [self sendMessage:@"Someone already has that username. Try another!\n"];
    }else{
        NSString *cns = [separateType objectAtIndex:0];
        NSLog(@"cn : %@",[cns substringFromIndex:16]);
        const char *const_cn=[[cns substringFromIndex:16] UTF8String];
        char *cn = calloc([[cns substringFromIndex:16] length]+1, 1);
        strncpy(cn, const_cn, [[cns substringFromIndex:16] length]);
        
        NSLog(@"sn : %@",[separateType objectAtIndex:1]);
        const char *const_sn=[[separateType objectAtIndex:1] UTF8String];
        char *sn = calloc([[separateType objectAtIndex:1] length]+1, 1);
        strncpy(sn, const_sn, [[separateType objectAtIndex:1]  length]);
        
        NSLog(@"pass : %@",[separateType objectAtIndex:3]);
        const char *const_pass=[[separateType objectAtIndex:3] UTF8String];
        char *pass = calloc([[separateType objectAtIndex:3] length]+1, 1);
        strncpy(pass, const_pass, [[separateType objectAtIndex:3]  length]);
        
        int i = [l addASyncWithCN:cn SN:sn uid:uid andPass:pass];
        if(i==111){
            [self sendMessage:@"Added successfully.\n"];
        }
    }

}

-(void)signIn:(NSString *)message{
    NSArray *separateType = [message componentsSeparatedByString:@"\t"];
    if (separateType.count<2) {
        NSLog(@"ERROR : can't separate to sign in");
        return;
    }
    
    ldapTest *l = [[ldapTest alloc]init];
    NSString *uis = [separateType objectAtIndex:0];
    const char *const_uid=[[uis substringFromIndex:7] UTF8String];
    char *uid = calloc([[uis substringFromIndex:7] length]+1, 1);
    strncpy(uid, const_uid, [[uis substringFromIndex:7] length]);
    
    const char *const_pass=[[separateType objectAtIndex:1] UTF8String];
    char *pass = calloc([[separateType objectAtIndex:1] length]+1, 1);
    strncpy(pass, const_pass, [[separateType objectAtIndex:1] length]);
    
    char *j = [l retrieveEntry:uid];
    NSString *result = [NSString stringWithCString:j encoding:NSUTF8StringEncoding];
    NSString *myPass = [NSString stringWithCString:pass encoding:NSUTF8StringEncoding];
    if (![result isEqualToString:myPass]) {
        NSLog(@"PASS : -%@-, REAL PASS : -%@-",myPass,result);
        NSLog(@"Username or password is not correct.");
        [self sendMessage:@"Username or password is not correct.\n"];
    }else{
        [self sendMessage:@"Signed in successfully.\n"];
    }
}
-(void)modifyStock:(NSArray *)separate{
    // modifyStock:%@:%@:%d",uid,txt.text,stockListNO
    //uid
    NSString *uid = [separate objectAtIndex:1];
    
    //a+a+a+a+a
    NSString *stock = [[separate objectAtIndex:2]lowercaseString];
    
    //stockListNO
    int stockNO = [[separate objectAtIndex:3]intValue];
    
    ldapTest *l = [[ldapTest alloc]init];
    const char *const_uid=[uid UTF8String];
    char *char_uid = calloc([uid length]+1, 1);
    strncpy(char_uid, const_uid, [uid length]);
    char *j = [l getStockList: char_uid];
    NSMutableString *result = [NSMutableString stringWithCString:j encoding:NSUTF8StringEncoding];
    if ([result isEqualToString:@"0"]) {
        //error uid
        NSLog(@"errorrrrr");
        [self sendMessage:@"Username is not found.\n"];
        return;
    }else{
        //found uid
        NSLog(@"found");
        
        
            
        NSUInteger count = 0, length = [result length];
        NSRange range = NSMakeRange(0, length);
        while(range.location != NSNotFound)
        {
            range = [result rangeOfString: @"\t" options:0 range:range];
            if(range.location != NSNotFound)
            {
                range = NSMakeRange(range.location + range.length, length - (range.location + range.length));
                if (count == stockNO) {
                    
                    [result insertString:stock atIndex:(int)range.location-1];
                    [result insertString:@"+" atIndex:(int)range.location-1];
                    
                    break;
                }
                count++;
            }
        }
        NSLog(@"count : %lu",(unsigned long)count);
        while (count<stockNO) {
            NSLog(@"while count : %lu",(unsigned long)count);
            
            if (count == stockNO ) {
                [result appendString:@"+"];
                [result appendString:stock];
            }
            [result appendString:@"\t"];
            count++;
        }
        if (range.location == NSNotFound) {
                [result appendString:@"+"];
                [result appendString:stock];
        }
        
        NSData *data = nil;
        
        for (int k = 0; k<stockList.count; k++) {
            
            NSRange r = NSMakeRange(1, [[[stockList objectAtIndex:k] objectAtIndex:0]length]-2);
            NSString *nameStock = [[[stockList objectAtIndex:k] objectAtIndex:0]substringWithRange:r];
            if ([stock caseInsensitiveCompare:nameStock]== NSOrderedSame && stock.length == nameStock.length) {
                NSLog(@"add new : %@",[stockList objectAtIndex:k]);
                //found
                NSArray *array = [[NSArray alloc]initWithObjects:@"modifyStock",[stockList objectAtIndex:k], nil];
                data  = [NSKeyedArchiver archivedDataWithRootObject:array];
            }
        }
        
        if (data == nil) {
            [self sendMessage:@"stock not found"];
            return;
        }
        
        const char *const_stock=[result UTF8String];
        char *char_stock = calloc([result length]+1, 1);
        strncpy(char_stock, const_stock, [result length]);
        int i = [l modify:char_stock withUID:char_uid];
        if(i==111){
            [self sendData:data];
        }
    }
}

-(void)getStockInfoOfUid:(NSArray *)separate{
    //uid
    NSString *uid = [separate objectAtIndex:1];
    //stockNO
    int stockNO = [[separate objectAtIndex:2]intValue];
    
    ldapTest *l = [[ldapTest alloc]init];
    const char *const_uid=[uid UTF8String];
    char *char_uid = calloc([uid length]+1, 1);
    strncpy(char_uid, const_uid, [uid length]);
    char *j = [l getStockList: char_uid];
    
    //a+b+c+d\te+f+g
    NSMutableString *result = [NSMutableString stringWithCString:j encoding:NSUTF8StringEncoding];
    
    NSMutableArray *countArr = [[NSMutableArray alloc]initWithArray:[result componentsSeparatedByString:@"\t" ]];
    
    
    if (stockNO > countArr.count -1) {
        for (int j = (int)countArr.count-1; j < stockNO; j++) {
            [countArr addObject:@"default"];
            [result appendString:@"\tdefault"];
        }
        NSLog(@"countArr : %lu , stockNO : %d",(unsigned long)countArr.count,stockNO);
        const char *const_stock=[result UTF8String];
        char *char_stock = calloc([result length]+1, 1);
        strncpy(char_stock, const_stock, [result length]);
        int resultMod = [l modify:char_stock withUID:char_uid];
    }
    
    NSMutableArray *myStockList = [[NSMutableArray alloc]init];
    NSArray *nameList = [[countArr objectAtIndex:stockNO ] componentsSeparatedByString:@"+"];
    
    NSLog(@"nameList : %@",nameList);
    for (int j = 1; j < nameList.count; j++) {
        for (int k = 0; k<stockList.count; k++) {
            NSRange r = NSMakeRange(1, [[[stockList objectAtIndex:k] objectAtIndex:0]length]-2);
            NSString *nameStock = [[[stockList objectAtIndex:k] objectAtIndex:0]substringWithRange:r];
            if ([[nameList objectAtIndex:j] caseInsensitiveCompare:nameStock]== NSOrderedSame) {
//                NSLog(@"\nnameStock : %@\nnameList[%d] : %@",nameStock,j,[nameList objectAtIndex:j]);
//                NSLog(@"stock : %@",[stockList objectAtIndex:k]);
                //found
                [myStockList addObject:[stockList objectAtIndex:k]];
                break;
            }
        }
        
    }
    NSNumber *totalList = [NSNumber numberWithLong:countArr.count];
    NSMutableString *header = [[NSMutableString alloc]initWithString:@"getStockInfoOfUid:"];
    [header appendString:[NSString stringWithFormat:@"%d",stockNO]];
    
    [myStockList insertObject:header atIndex:0];
    [myStockList addObject:totalList];
    NSLog(@"myStockList : %@",myStockList);
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:myStockList];
    [self sendData:data];
}

-(void)removeStock:(NSArray *)separate{
    // removeStock:%@:%@:%d",uid,stock,stockListNO
    //uid
    NSString *uid = [separate objectAtIndex:1];
    
    //a+a+a+a+a
    NSString *stock = [separate objectAtIndex:2];
    NSArray *removeStockArr = [stock componentsSeparatedByString:@"+"];
    
    //stockListNO
    int stockNO = [[separate objectAtIndex:3]intValue];
    
    ldapTest *l = [[ldapTest alloc]init];
    const char *const_uid=[uid UTF8String];
    char *char_uid = calloc([uid length]+1, 1);
    strncpy(char_uid, const_uid, [uid length]);
    char *j = [l getStockList: char_uid];
    NSMutableString *result = [NSMutableString stringWithCString:j encoding:NSUTF8StringEncoding];
    if ([result isEqualToString:@"0"]) {
        //error uid
        NSLog(@"errorrrrr");
        [self sendMessage:@"Username is not found.\n"];
        return;
    }else{
        //found uid
        NSLog(@"found");
        NSMutableArray *totalStockArr = [[NSMutableArray alloc]initWithArray:[result componentsSeparatedByString:@"\t"]];
        NSMutableArray *targetStockArr = [[NSMutableArray alloc]initWithArray:[[totalStockArr objectAtIndex:stockNO]componentsSeparatedByString:@"+"]];
        for (int n = 0; n<removeStockArr.count; n++) {
            [targetStockArr removeObject:[[removeStockArr objectAtIndex:n]lowercaseString]];
        }
        [totalStockArr replaceObjectAtIndex:stockNO withObject:[targetStockArr componentsJoinedByString:@"+"]];
        NSString *targetStock = [totalStockArr componentsJoinedByString:@"\t"];
        NSLog(@"targetStock : %@",targetStockArr);
        
        const char *const_stock=[targetStock UTF8String];
        char *char_stock = calloc([targetStock length]+1, 1);
        strncpy(char_stock, const_stock, [targetStock length]);
        int i = [l modify:char_stock withUID:char_uid];
        if(i==111){
            NSLog(@"modified successful!!!");
        }
    }
}

-(void)moveStock:(NSArray *)separate{
    NSLog(@"***********************************");
    NSLog(@"separate : %@",separate);
    // moveStock:%@:%d:%d",uid,stockListNO,sourceIndex,destinationIndex
    //uid
    NSString *uid = [separate objectAtIndex:1];
    int sourceIndex = [[separate objectAtIndex:3]intValue];
    int destinationIndex = [[separate objectAtIndex:4]intValue];
    
    //stockListNO
    int stockNO = [[separate objectAtIndex:2]intValue];
    
    ldapTest *l = [[ldapTest alloc]init];
    const char *const_uid=[uid UTF8String];
    char *char_uid = calloc([uid length]+1, 1);
    strncpy(char_uid, const_uid, [uid length]);
    char *j = [l getStockList: char_uid];
    NSMutableString *result = [NSMutableString stringWithCString:j encoding:NSUTF8StringEncoding];
    if ([result isEqualToString:@"0"]) {
        //error uid
        NSLog(@"errorrrrr");
        [self sendMessage:@"Username is not found.\n"];
        return;
    }else{
        //found uid
        NSLog(@"found");
        NSLog(@"***********************************");
        NSLog(@"result : %@",result);
        NSMutableArray *totalStockArr = [[NSMutableArray alloc]initWithArray:[result componentsSeparatedByString:@"\t"]];
        NSMutableArray *targetStockArr = [[NSMutableArray alloc]initWithArray:[[totalStockArr objectAtIndex:stockNO]componentsSeparatedByString:@"+"]];
        
        NSString *name = [targetStockArr objectAtIndex:sourceIndex];
        [targetStockArr removeObjectAtIndex:sourceIndex];
        [targetStockArr insertObject:name atIndex:destinationIndex];
        
        [totalStockArr replaceObjectAtIndex:stockNO withObject:[targetStockArr componentsJoinedByString:@"+"]];
        NSString *targetStock = [totalStockArr componentsJoinedByString:@"\t"];
        
        NSLog(@"***********************************");
        NSLog(@"targetStock : %@",targetStock);
        
        const char *const_stock=[targetStock UTF8String];
        char *char_stock = calloc([targetStock length]+1, 1);
        strncpy(char_stock, const_stock, [targetStock length]);
        int i = [l modify:char_stock withUID:char_uid];
        if(i==111){
            NSLog(@"modified successful!");
        }
    }
}
-(void)getTheseStock:(NSArray *)separate{
    NSMutableArray *myStockList = [[NSMutableArray alloc]init];
    NSString *str = [separate objectAtIndex:1];
    NSArray *nameList = [str componentsSeparatedByString:@"+"];
    NSLog(@"str : %@",str);
    for (int j = 0; j < nameList.count; j++) {
        for (int k = 0; k<stockList.count; k++) {
            NSRange r = NSMakeRange(1, [[[stockList objectAtIndex:k] objectAtIndex:0]length]-2);
            NSString *nameStock = [[[stockList objectAtIndex:k] objectAtIndex:0]substringWithRange:r];
            if ([[nameList objectAtIndex:j] caseInsensitiveCompare:nameStock]== NSOrderedSame) {
                //found
                [myStockList insertObject:[stockList objectAtIndex:k] atIndex:0];
            }
        }
    }
    [myStockList insertObject:@"getTheseStock" atIndex:0];
//    NSLog(@"myStockList : %@",myStockList);
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:myStockList];
    [self sendData:data];
}
-(void)getStockDetail:(NSString *)stockName{
    NSLog(@"stockName : %@",stockName);
    for (int k = 0; k<stockList.count; k++) {
        NSRange r = NSMakeRange(1, [[[stockList objectAtIndex:k] objectAtIndex:0]length]-2);
        NSString *nameStock = [[[stockList objectAtIndex:k] objectAtIndex:0]substringWithRange:r];
        if ([stockName caseInsensitiveCompare:nameStock]== NSOrderedSame) {
            //found
            NSArray *array = [[NSArray alloc]initWithObjects:@"getStockDetail",[stockList objectAtIndex:k], nil];
            NSData *data = [NSKeyedArchiver archivedDataWithRootObject:array];
            [self sendData:data];
            return;
        }
    }
    [self sendMessage:@"not found data"];
}

-(void)getAllStockList:(NSArray *)separate{
    //uid
    NSString *uid = [separate objectAtIndex:1];
    
    ldapTest *l = [[ldapTest alloc]init];
    const char *const_uid=[uid UTF8String];
    char *char_uid = calloc([uid length]+1, 1);
    strncpy(char_uid, const_uid, [uid length]);
    char *j = [l getStockList: char_uid];
    
    //a+b+c+d\te+f+g
    NSMutableString *result = [NSMutableString stringWithCString:j encoding:NSUTF8StringEncoding];
    NSMutableArray *totalList = [[NSMutableArray alloc]initWithArray:[result componentsSeparatedByString:@"\t" ]];
    
    NSLog(@"totalList : %@",totalList);
    
    NSMutableArray *myStockList = [[NSMutableArray alloc]init];
    [myStockList insertObject:@"getAllStockList" atIndex:0];
    [myStockList addObject:totalList];
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:myStockList];
    [self sendData:data];
}

-(void)removeList:(NSArray *)separate{
    // removeList:%@:%d",uid,1+2+...
    //uid
    NSString *uid = [separate objectAtIndex:1];
    
    //1+2+3..
    NSString *stock = [separate objectAtIndex:2];
    NSArray *removeStockArr = [stock componentsSeparatedByString:@"+"];
    
    
    ldapTest *l = [[ldapTest alloc]init];
    const char *const_uid=[uid UTF8String];
    char *char_uid = calloc([uid length]+1, 1);
    strncpy(char_uid, const_uid, [uid length]);
    char *j = [l getStockList: char_uid];
    NSMutableString *result = [NSMutableString stringWithCString:j encoding:NSUTF8StringEncoding];
    if ([result isEqualToString:@"0"]) {
        //error uid
        NSLog(@"errorrrrr");
        [self sendMessage:@"Username is not found.\n"];
        return;
    }else{
        //found uid
        NSLog(@"found");
        NSMutableArray *totalStockArr = [[NSMutableArray alloc]initWithArray:[result componentsSeparatedByString:@"\t"]];
        
        for (int n = 0; n<removeStockArr.count; n++) {
            [totalStockArr removeObjectAtIndex:[[removeStockArr objectAtIndex:n] intValue]];
        }
        NSString *targetStock = [totalStockArr componentsJoinedByString:@"\t"];
        NSLog(@"targetStock : %@",targetStock);
        
        const char *const_stock=[targetStock UTF8String];
        char *char_stock = calloc([targetStock length]+1, 1);
        strncpy(char_stock, const_stock, [targetStock length]);
        int i = [l modify:char_stock withUID:char_uid];
        if(i==111){
            NSLog(@"modified successful!!!");
        }
    }
}

-(void)reorderList:(NSArray *)separate{
    // moveStock:%@:%d:%d",uid,sourceIndex,destinationIndex
    //uid
    NSString *uid = [separate objectAtIndex:1];
    int sourceIndex = [[separate objectAtIndex:2]intValue];
    int destinationIndex = [[separate objectAtIndex:3]intValue];
    
    
    ldapTest *l = [[ldapTest alloc]init];
    const char *const_uid=[uid UTF8String];
    char *char_uid = calloc([uid length]+1, 1);
    strncpy(char_uid, const_uid, [uid length]);
    char *j = [l getStockList: char_uid];
    NSMutableString *result = [NSMutableString stringWithCString:j encoding:NSUTF8StringEncoding];
    if ([result isEqualToString:@"0"]) {
        //error uid
        NSLog(@"errorrrrr");
        [self sendMessage:@"Username is not found.\n"];
        return;
    }else{
        //found uid
        NSLog(@"found");
        NSMutableArray *totalStockArr = [[NSMutableArray alloc]initWithArray:[result componentsSeparatedByString:@"\t"]];
        
        NSString *name = [totalStockArr objectAtIndex:sourceIndex];
        [totalStockArr removeObjectAtIndex:sourceIndex];
        [totalStockArr insertObject:name atIndex:destinationIndex];
        
        NSString *targetStock = [totalStockArr componentsJoinedByString:@"\t"];
        
        
        const char *const_stock=[targetStock UTF8String];
        char *char_stock = calloc([targetStock length]+1, 1);
        strncpy(char_stock, const_stock, [targetStock length]);
        int i = [l modify:char_stock withUID:char_uid];
        if(i==111){
            NSLog(@"modified successful!");
        }
    }
}

@end
