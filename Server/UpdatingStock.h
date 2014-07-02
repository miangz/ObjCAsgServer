//
//  UpdatingStock.h
//  Server
//
//  Created by miang on 7/2/2557 BE.
//  Copyright (c) 2557 miang. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface UpdatingStock : NSObject

@property NSMutableArray *stockList;

- (void)startUpdateStock;
-(void) updateStock;
@end
