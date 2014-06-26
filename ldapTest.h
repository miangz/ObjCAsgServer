//
//  ldapTest.h
//  Server
//
//  Created by miang on 5/2/2557 BE.
//  Copyright (c) 2557 miang. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ldapTest : NSObject

-(char *)retrieveEntry:(char *)uid;
-(char *)getStockList:(char *)uid;
-(int)addASyncWithCN:(char*)cname SN:(char*)sname uid:(char*)uid andPass:(char*)pass;
-(int) modify:(char *)stock withUID:(char *)uid;
@end
