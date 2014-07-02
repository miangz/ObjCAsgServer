//
//  LdapManager.m
//  Server
//
//  Created by miang on 7/2/2557 BE.
//  Copyright (c) 2557 miang. All rights reserved.
//

#import "LdapManager.h"
#import "ldapTest.h"
#import "TCPServer.h"

@implementation LdapManager
@synthesize stockList;

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
        TCPServer *server = [TCPServer sharedManager];
        [server sendMessage:@"Someone already has that username. Try another!\n"];
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
            TCPServer *server = [TCPServer sharedManager];
            [server sendMessage:@"Added successfully.\n"];
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
        TCPServer *server = [TCPServer sharedManager];
        [server sendMessage:@"Username or password is not correct.\n"];
    }else{
        TCPServer *server = [TCPServer sharedManager];
        [server sendMessage:@"Signed in successfully.\n"];
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
        TCPServer *server = [TCPServer sharedManager];
        [server sendMessage:@"Username is not found.\n"];
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
        
        if (count == 0 && stockNO == 0) {
            [result appendString:@"+"];
            [result appendString:stock];
        }else if (range.location == NSNotFound) {
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
            TCPServer *server = [TCPServer sharedManager];
            [server sendMessage:@"stock not found"];
            return;
        }
        
        const char *const_stock=[result UTF8String];
        char *char_stock = calloc([result length]+1, 1);
        strncpy(char_stock, const_stock, [result length]);
        int i = [l modify:char_stock withUID:char_uid];
        if(i==111){
            TCPServer *server = [TCPServer sharedManager];
            [server sendData:data];
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
    NSMutableString *result = [[NSMutableString alloc]initWithString:[NSString stringWithUTF8String:j]];
    //[NSMutableString stringWithCString:j encoding:NSUTF8StringEncoding];
    
    NSMutableArray *countArr = [[NSMutableArray alloc]initWithArray:[result componentsSeparatedByString:@"\t" ]];
    
    
    if (stockNO >= countArr.count) {
        for (int j = (int)countArr.count; j <= stockNO; j++) {
            [countArr addObject:[NSString stringWithFormat:@"%d",j+1]];
            [result appendString:[NSString stringWithFormat:@"\t%d",j+1]];
        }
        NSLog(@"countArr : %lu , stockNO : %d",(unsigned long)countArr.count,stockNO);
        //        const char *const_stock=[result UTF8String];
        //        char *char_stock = calloc([result length]+1, 1);
        //        strncpy(char_stock, const_stock, [result length]);
        NSString *ss =[NSString stringWithFormat:@"%@",result];
        
        const char *const_stock=[ss UTF8String];
        char *char_stock = calloc([ss length]+1, 1);
        strncpy(char_stock, const_stock, [ss length]);
        int resultMod = [l modify:char_stock withUID:char_uid];
        
    }
    
    NSMutableArray *myStockList = [[NSMutableArray alloc]init];
    [countArr sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
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
    NSNumber *totalList = [NSNumber numberWithInteger:countArr.count];
    NSMutableString *header = [[NSMutableString alloc]initWithString:@"getStockInfoOfUid:"];
    [header appendString:[NSString stringWithFormat:@"%d",stockNO]];
    
    [myStockList insertObject:header atIndex:0];
    [myStockList addObject:totalList];
    NSLog(@"myStockList : %@",myStockList);
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:myStockList];
    TCPServer *server = [TCPServer sharedManager];
    [server sendData:data];
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
        TCPServer *server = [TCPServer sharedManager];
        [server sendMessage:@"Username is not found.\n"];
        return;
    }else{
        //found uid
        NSLog(@"found");
        NSMutableArray *totalStockArr = [[NSMutableArray alloc]initWithArray:[result componentsSeparatedByString:@"\t"]];
        [totalStockArr sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
        
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
        TCPServer *server = [TCPServer sharedManager];
        [server sendMessage:@"Username is not found.\n"];
        return;
    }else{
        //found uid
        NSLog(@"found");
        NSLog(@"***********************************");
        NSLog(@"result : %@",result);
        NSMutableArray *totalStockArr = [[NSMutableArray alloc]initWithArray:[result componentsSeparatedByString:@"\t"]];
        [totalStockArr sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
        
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
    TCPServer *server = [TCPServer sharedManager];
    [server sendData:data];
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
            TCPServer *server = [TCPServer sharedManager];
            [server sendData:data];
            return;
        }
    }
    TCPServer *server = [TCPServer sharedManager];
    [server sendMessage:@"not found data"];
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
    [totalList sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    NSLog(@"totalList : %@",totalList);
    
    NSMutableArray *myStockList = [[NSMutableArray alloc]init];
    [myStockList insertObject:@"getAllStockList" atIndex:0];
    [myStockList addObject:totalList];
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:myStockList];
    TCPServer *server = [TCPServer sharedManager];
    [server sendData:data];
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
        TCPServer *server = [TCPServer sharedManager];
        [server sendMessage:@"Username is not found.\n"];
        return;
    }else{
        //found uid
        NSLog(@"found");
        NSMutableArray *totalStockArr = [[NSMutableArray alloc]initWithArray:[result componentsSeparatedByString:@"\t"]];
        [totalStockArr sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
        
        for (int n = 0; n<removeStockArr.count; n++) {
            [totalStockArr removeObjectAtIndex:[[removeStockArr objectAtIndex:n] intValue]];
            for (int k = [[removeStockArr objectAtIndex:n] intValue] ; k <totalStockArr.count; k++) {
                NSString *name = [totalStockArr objectAtIndex:k];
                NSString *source = [NSString stringWithFormat:@"%d",k+2];
                NSString *des = [NSString stringWithFormat:@"%d",k+1];
                
                name = [name stringByReplacingOccurrencesOfString:source
                                                       withString:des];
                [totalStockArr replaceObjectAtIndex:k withObject:name];
            }
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
        TCPServer *server = [TCPServer sharedManager];
        [server sendMessage:@"Username is not found.\n"];
        return;
    }else{
        //found uid
        NSLog(@"found");
        NSMutableArray *totalStockArr = [[NSMutableArray alloc]initWithArray:[result componentsSeparatedByString:@"\t"]];
        [totalStockArr sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
        
        NSString *name = [totalStockArr objectAtIndex:sourceIndex];
        NSString *source = [NSString stringWithFormat:@"%d",sourceIndex];
        NSString *des = [NSString stringWithFormat:@"%d",destinationIndex];
        
        [name stringByReplacingOccurrencesOfString:source
                                        withString:des];
        [totalStockArr removeObjectAtIndex:sourceIndex];
        [totalStockArr insertObject:name atIndex:destinationIndex];
        
        for (int n = destinationIndex + 1; n <totalStockArr.count; n++) {
            NSString *name = [totalStockArr objectAtIndex:n];
            NSString *source = [NSString stringWithFormat:@"%d",n];
            NSString *des = [NSString stringWithFormat:@"%d",n+1];
            
            [name stringByReplacingOccurrencesOfString:source
                                            withString:des];
            [totalStockArr replaceObjectAtIndex:n withObject:name];
        }
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
