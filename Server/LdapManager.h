//
//  LdapManager.h
//  Server
//
//  Created by miang on 7/2/2557 BE.
//  Copyright (c) 2557 miang. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LdapManager : NSObject

@property NSMutableArray *stockList;

-(void)createAnAccount:(NSString *)message;
-(void)signIn:(NSString *)message;
-(void)modifyStock:(NSArray *)separate;
-(void)getStockInfoOfUid:(NSArray *)separate;
-(void)removeStock:(NSArray *)separate;
-(void)moveStock:(NSArray *)separate;
-(void)getTheseStock:(NSArray *)separate;
-(void)getStockDetail:(NSString *)stockName;
-(void)getAllStockList:(NSArray *)separate;
-(void)removeList:(NSArray *)separate;
-(void)reorderList:(NSArray *)separate;

@end
