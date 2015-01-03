//
//  FlickScroll.m
//  FlickScroll
//
//  Created by Mathew Huusko V on 1/2/15.
//  Copyright (c) 2015 Mathew Huusko V. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static void M5SwizzleMethod(Class clazz, SEL original, SEL alternate) {
    Method origMethod = class_getInstanceMethod(clazz, original);
    Method newMethod = class_getInstanceMethod(clazz, alternate);
    
    if(class_addMethod(clazz, original, method_getImplementation(newMethod), method_getTypeEncoding(newMethod))) {
        class_replaceMethod(clazz, alternate, method_getImplementation(origMethod), method_getTypeEncoding(origMethod));
    } else {
        method_exchangeImplementations(origMethod, newMethod);
    }
}

@implementation UIScrollView (FlickScroll)

const void* M5_scrollTouchCount = &M5_scrollTouchCount;
const void* M5_scrollTouchPoint = &M5_scrollTouchPoint;

- (void)M5_scrollViewWillBeginDragging {
    objc_setAssociatedObject(self, M5_scrollTouchCount, @(self.panGestureRecognizer.numberOfTouches), OBJC_ASSOCIATION_RETAIN);
    objc_setAssociatedObject(self, M5_scrollTouchPoint, [NSValue valueWithCGPoint:[self.panGestureRecognizer locationInView:self]], OBJC_ASSOCIATION_RETAIN);
}

- (void)M5_scrollViewDidEndDraggingWithDeceleration:(BOOL)flicked {
    if (flicked && [objc_getAssociatedObject(self, M5_scrollTouchCount) unsignedIntegerValue] == 2 && self.isScrollEnabled && !self.isPagingEnabled && ![[self valueForKey:@"_horizontalVelocity"] doubleValue]) {
        int scrollDirection = [[self valueForKey:@"_verticalVelocity"] doubleValue] > 0 ? 1 : -1;
        
        CGPoint scrollLocation = [objc_getAssociatedObject(self, M5_scrollTouchPoint) CGPointValue];
        
        CGPoint contentOffset = self.contentOffset;
        
        if (scrollDirection > 0) {
            contentOffset.y = scrollLocation.y;
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self setContentOffset:contentOffset animated:YES];
            });
        }
    }
    
    [self M5_scrollViewDidEndDraggingWithDeceleration:flicked];
}

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        M5SwizzleMethod(self, @selector(_scrollViewDidEndDraggingWithDeceleration:), @selector(M5_scrollViewDidEndDraggingWithDeceleration:));
        
        M5SwizzleMethod(self, @selector(_scrollViewWillBeginDragging), @selector(M5_scrollViewWillBeginDragging));
    });
}

@end

@interface M5FlickScroll : NSObject
    
@end

@implementation M5FlickScroll

- (instancetype)init {
    if (self = [super init]) {
        NSLog(@"FlickScroll init-ed.");
    }
    
    return self;
}

+ (instancetype)sharedInstance {
    static id sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = self.new;
    });
    return sharedInstance;
}

+ (void)load {
    [self sharedInstance];
}

@end
