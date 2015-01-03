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

const void* scrollTouchCount = &scrollTouchCount;
const void* scrollTouchPoint = &scrollTouchPoint;
const void* scrollTouchVelocity = &scrollTouchVelocity;

- (void)M5_scrollViewWillBeginDragging {
    objc_setAssociatedObject(self, scrollTouchCount, @(self.panGestureRecognizer.numberOfTouches), OBJC_ASSOCIATION_RETAIN);
    objc_setAssociatedObject(self, scrollTouchPoint, [NSValue valueWithCGPoint:[self.panGestureRecognizer locationInView:self]], OBJC_ASSOCIATION_RETAIN);
}

- (BOOL)M5_scrollViewWillEndDraggingWithDeceleration:(BOOL)flicked {
    objc_setAssociatedObject(self, scrollTouchVelocity, [NSValue valueWithCGPoint:CGPointMake([[self valueForKey:@"_horizontalVelocity"] doubleValue], [[self valueForKey:@"_verticalVelocity"] doubleValue])], OBJC_ASSOCIATION_RETAIN);
    
    return [self M5_scrollViewWillEndDraggingWithDeceleration:flicked];
}

- (void)M5_scrollViewDidEndDraggingWithDeceleration:(BOOL)flicked {
    if (active && self.scrollEnabled && !self.isPagingEnabled) {
        CGPoint velocity = [objc_getAssociatedObject(self, scrollTouchVelocity) CGPointValue];
        NSUInteger touchCount = [objc_getAssociatedObject(self, scrollTouchCount) unsignedIntegerValue];
        
        if (((twoFingers && touchCount == 2) || (!twoFingers && touchCount == 1)) && fabs(velocity.y / (velocity.x + 0.0001)) > 10) {
            CGPoint scrollLocation = [objc_getAssociatedObject(self, scrollTouchPoint) CGPointValue];
            
            CGPoint contentOffset = self.contentOffset;
            
            if (velocity.y > 0) {
                contentOffset.y = scrollLocation.y - self.frame.size.height / 7;
            } else {
                contentOffset.y -= self.frame.size.height - (scrollLocation.y - contentOffset.y) - self.frame.size.height / 10;
            }
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0), dispatch_get_main_queue(), ^{
                [self setContentOffset:contentOffset animated:YES];
            });
        }
    }
    
    [self M5_scrollViewDidEndDraggingWithDeceleration:flicked];
}

static BOOL active;
static BOOL twoFingers;

static void preferencesChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    NSDictionary *prefs;
    if (!(prefs = [[NSDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/Preferences/com.mhuusko5.FlickScroll.plist"])) {
        [prefs writeToFile:@"/var/mobile/Library/Preferences/com.mhuusko5.FlickScroll.plist" atomically:YES];
        prefs = [[NSDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/Preferences/com.mhuusko5.FlickScroll.plist"];
    }
    
    if (prefs[@"Active"]) {
        active = [prefs[@"Active"] boolValue];
    } else {
        active = YES;
    }
    
    if (prefs[@"TwoFinger"]) {
        twoFingers = [prefs[@"TwoFinger"] boolValue];
    } else {
        twoFingers = NO;
    }
    
    if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_7_1 && name) {
        CFPreferencesAppSynchronize(CFSTR("com.mhuusko5.FlickScroll"));
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            preferencesChanged(NULL, NULL, NULL, NULL, NULL);
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                preferencesChanged(NULL, NULL, NULL, NULL, NULL);
            });
        });
    }
}

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        M5SwizzleMethod(self, @selector(_scrollViewWillBeginDragging), @selector(M5_scrollViewWillBeginDragging));
        
        M5SwizzleMethod(self, @selector(_scrollViewWillEndDraggingWithDeceleration:), @selector(M5_scrollViewWillEndDraggingWithDeceleration:));
        
        M5SwizzleMethod(self, @selector(_scrollViewDidEndDraggingWithDeceleration:), @selector(M5_scrollViewDidEndDraggingWithDeceleration:));
        
        preferencesChanged(NULL, NULL, CFSTR(""), NULL, NULL);
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)preferencesChanged, CFSTR("com.mhuusko5.FlickScroll-preferencesChanged"), NULL, CFNotificationSuspensionBehaviorCoalesce);
    });
}

@end