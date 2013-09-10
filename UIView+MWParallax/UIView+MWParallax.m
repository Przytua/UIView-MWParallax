//
//  UIView+MWParallax.m
//  UIView+MWParallax
//
//  Created by Łukasz Przytuła on 06.09.2013.
//  Copyright (c) 2013 Mildware. All rights reserved.
//

#if __has_feature(objc_arc)

#import "UIView+MWParallax.h"
#import <objc/runtime.h>
#import <CoreMotion/CoreMotion.h>

#pragma mark - Parallax motion observer object

@interface MWParallaxMotionChangesObserverObject : NSObject

@property (nonatomic, weak) UIView *view;

@end

@implementation MWParallaxMotionChangesObserverObject

- (instancetype)initWithView:(UIView *)view
{
  self = [super init];
  if (self) {
    self.view = view;
  }
  return self;
}

@end

#pragma mark - UIView+MWParallax

static CMMotionManager *_mw_paralaxMotionManager;
static CMAttitude *_mw_referenceAttitude;
static CMAttitude *_mw_currentAttitude;
static NSUInteger mw_viewsRegisteredForParallax;
static NSUInteger mw_retriesSinceMotionUpdatesBegan;
static CGPoint _mw_attitudeDifference;
static NSMutableArray *_mw_parallaxMotionChangesObservers;

static const NSString * kMLDWRParallaxDepthKey = @"kMLDWRParallaxDepthKey";

NSString * const kMLDWRMotionManagerUpdatedNotification = @"kMLDWRMotionManagerUpdatedNotification";

@interface UIView ()

@property (nonatomic, copy) CMAttitude *mw_referenceAttitude;
@property (nonatomic, copy) CMAttitude *mw_currentAttitude;
@property (atomic) CGPoint mw_attitudeDifference;
@property (nonatomic, readonly) NSMutableArray *mw_parallaxMotionChangesObservers;
@property (nonatomic, readonly) CMMotionManager *parallaxMotionManager;

@end

@implementation UIView (MWParallax)

#pragma mark - accessors

- (void)setIOS6ParallaxIntensity:(CGFloat)iOS6ParallaxIntensity
{
  if (self.iOS6ParallaxIntensity == iOS6ParallaxIntensity)
    return;
  
  if (iOS6ParallaxIntensity == 0.0) {
    [self endParallaxUpdates];
  } else if (self.iOS6ParallaxIntensity == 0.0) {
    [self beginParallaxUpdates];
  }
  
  objc_setAssociatedObject(self, (__bridge const void *)(kMLDWRParallaxDepthKey), @(iOS6ParallaxIntensity), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

-(CGFloat)iOS6ParallaxIntensity
{
  NSNumber * val = objc_getAssociatedObject(self, (__bridge const void *)(kMLDWRParallaxDepthKey));
  if (!val) {
    return 0.0;
  }
  return [val doubleValue];
}

- (void)setMw_referenceAttitude:(CMAttitude *)mw_referenceAttitude
{
  _mw_referenceAttitude = mw_referenceAttitude;
}

- (CMAttitude *)mw_referenceAttitude
{
  return _mw_referenceAttitude;
}

- (void)setMw_currentAttitude:(CMAttitude *)mw_currentAttitude
{
  _mw_currentAttitude = mw_currentAttitude;
}

- (CMAttitude *)mw_currentAttitude
{
  return _mw_currentAttitude;
}

- (void)setMw_attitudeDifference:(CGPoint)mw_attitudeDifference
{
  _mw_attitudeDifference = mw_attitudeDifference;
}

- (CGPoint)mw_attitudeDifference
{
  return _mw_attitudeDifference;
}

- (NSArray *)mw_parallaxMotionChangesObservers
{
  if (!_mw_parallaxMotionChangesObservers) {
    _mw_parallaxMotionChangesObservers = [[NSMutableArray alloc] init];
  }
  return _mw_parallaxMotionChangesObservers;
}
#pragma mark - motion

- (CMMotionManager *)parallaxMotionManager {
  if (!_mw_paralaxMotionManager) {
    _mw_paralaxMotionManager = [[CMMotionManager alloc] init];
  }
  return _mw_paralaxMotionManager;
}

- (void)motionsUpdated
{
  CGFloat parallaxIntensity = self.iOS6ParallaxIntensity;
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    CGPoint attitudeDifference = CGPointMake(self.mw_attitudeDifference.x * self.iOS6ParallaxIntensity, self.mw_attitudeDifference.y * self.iOS6ParallaxIntensity);
    CGAffineTransform newTransform;
    if (self.iOS6ParallaxIntensity > 0) {
      newTransform = CGAffineTransformMakeTranslation(MAX(MIN(parallaxIntensity, attitudeDifference.x), -parallaxIntensity),
                                                      MAX(MIN(parallaxIntensity, attitudeDifference.y), -parallaxIntensity));
    } else {
      newTransform = CGAffineTransformMakeTranslation(MIN(MAX(parallaxIntensity, attitudeDifference.x), -parallaxIntensity),
                                                      MIN(MAX(parallaxIntensity, attitudeDifference.y), -parallaxIntensity));
    }
    dispatch_async(dispatch_get_main_queue(), ^{
      self.transform = newTransform;
    });
  });
}

static NSOperationQueue *parallaxOperationQueue;

- (void)beginParallaxUpdates {
  [self.mw_parallaxMotionChangesObservers addObject:[[MWParallaxMotionChangesObserverObject alloc] initWithView:self]];
  if (mw_viewsRegisteredForParallax++ == 0) {
    self.mw_referenceAttitude = nil;
    mw_retriesSinceMotionUpdatesBegan = 0;
    CMMotionManager *motionManager = self.parallaxMotionManager;
    
    if (motionManager.deviceMotionAvailable) {
      if (!parallaxOperationQueue) {
        parallaxOperationQueue = [[NSOperationQueue alloc] init];
      }
      [motionManager
       startDeviceMotionUpdatesToQueue:parallaxOperationQueue
       withHandler: ^(CMDeviceMotion *motion, NSError *error) {
         if (!self.mw_referenceAttitude && mw_retriesSinceMotionUpdatesBegan++ == 4) {
           self.mw_referenceAttitude = motion.attitude;
           self.mw_currentAttitude = motion.attitude;
         } else if (self.mw_referenceAttitude) {
           if (self.mw_currentAttitude.pitch != motion.attitude.pitch || self.mw_currentAttitude.roll != motion.attitude.roll) {
             self.mw_currentAttitude = motion.attitude;
             self.mw_attitudeDifference = CGPointMake((self.mw_currentAttitude.roll - self.mw_referenceAttitude.roll), (self.mw_currentAttitude.pitch - self.mw_referenceAttitude.pitch));
             NSMutableArray *observersToRemove = [[NSMutableArray alloc] init];
             for (MWParallaxMotionChangesObserverObject *observer in self.mw_parallaxMotionChangesObservers) {
               if (!observer.view) {
                 [observersToRemove addObject:observer];
               } else {
                 [observer.view motionsUpdated];
               }
             }
             if ([observersToRemove count] > 0) {
               [self.mw_parallaxMotionChangesObservers removeObjectsInArray:observersToRemove];
             }
           }
         }
       }];
    }
  }
}

- (void)endParallaxUpdates {
  self.transform = CGAffineTransformIdentity;
  NSArray *observerWithSelf = [self.mw_parallaxMotionChangesObservers filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"view == %@", self]];
  [self.mw_parallaxMotionChangesObservers removeObjectsInArray:observerWithSelf];
  if (--mw_viewsRegisteredForParallax == 0) {
    CMMotionManager *motionManager = self.parallaxMotionManager;
    if ([motionManager isDeviceMotionActive] == YES) {
      [motionManager stopDeviceMotionUpdates];
    }
  }
}

@end

#endif
