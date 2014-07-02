//
//  UpdatingStock.m
//  Server
//
//  Created by miang on 7/2/2557 BE.
//  Copyright (c) 2557 miang. All rights reserved.
//

#import "UpdatingStock.h"

@implementation UpdatingStock
@synthesize stockList;
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

@end
