//
//  NSMutableArray+MoveIndex.m
//  asignment1
//
//  Created by miang on 6/11/2557 BE.
//  Copyright (c) 2557 miang. All rights reserved.
//

#import "NSMutableArray+MoveIndex.h"

@implementation NSMutableArray (MoveIndex)
- (void)moveObjectAtIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex
{
    id object = [self objectAtIndex:fromIndex];
    [self removeObjectAtIndex:fromIndex];
    [self insertObject:object atIndex:toIndex];
}
@end
