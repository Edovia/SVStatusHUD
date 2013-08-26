//
//  SVStatusHUD.m
//
//  Created by Sam Vermette on 17.11.11.
//  Copyright 2011 Sam Vermette. All rights reserved.
//
//  https://github.com/samvermette/SVStatusHUD
//

#import "SVStatusHUD.h" 
#import "UIImage+ImageEffects.h"
#import "UIImage+Rotate.h"
#import <QuartzCore/QuartzCore.h>

#define SVStatusHUDVisibleDuration 1.0f
#define SVStatusHUDFadeOutDuration 1.0f
#define SVStatusHUDRingRadius 10

#define MOTION_EFFECT_MULTIPLIER 9

NSString* const SVStatusHUDDidFinishNotification = @"SVStatusHUDDidFinishNotification";

@interface SVStatusImage : UIView

@property (nonatomic, retain) UIImage *image;

@end


@interface SVStatusHUD ()

@property (nonatomic, retain) NSTimer *fadeOutTimer;
@property (nonatomic, readonly) UIWindow *overlayWindow;
@property (nonatomic, readonly) UIImageView *hudView;
@property (nonatomic, readonly) UILabel *stringLabel;
@property (nonatomic, readonly) SVStatusImage *imageView;

- (void)showWithImage:(UIImage*)image status:(NSString*)string duration:(NSTimeInterval)duration;
- (void)setStatus:(NSString*)string;
- (void)registerNotifications;
- (void)positionHUD:(NSNotification*)notification;

- (void)dismiss;

@end


@implementation SVStatusHUD

@synthesize overlayWindow, hudView, fadeOutTimer, stringLabel, imageView;

static SVStatusHUD *sharedView = nil;

+ (SVStatusHUD*)sharedView {
	
	if(sharedView == nil)
		sharedView = [[SVStatusHUD alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	
	return sharedView;
}


+ (void)setStatus:(NSString *)string {
	[[SVStatusHUD sharedView] setStatus:string];
}

#pragma mark - Show Methods

+ (void)showWithImage:(UIImage*)image {
    [SVStatusHUD showWithImage:image status:nil duration:SVStatusHUDVisibleDuration];
}

+ (void)showWithImage:(UIImage*)image status:(NSString*)string {
    [SVStatusHUD showWithImage:image status:string duration:SVStatusHUDVisibleDuration];
}

+ (void)showWithImage:(UIImage*)image status:(NSString*)string duration:(NSTimeInterval)duration {
    [[SVStatusHUD sharedView] showWithImage:image status:string duration:duration];
}


#pragma mark - Instance Methods

- (id)initWithFrame:(CGRect)frame {
	
    if ((self = [super initWithFrame:frame])) {
        [self.overlayWindow addSubview:self];
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO;
		self.alpha = 0;
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    }
	
    return self;
}

- (BOOL)iOS7Style {
    return [[[UIApplication sharedApplication].delegate window] respondsToSelector:@selector(drawViewHierarchyInRect:afterScreenUpdates:)];
}

- (void)setStatus:(NSString *)string {
	
    CGFloat hudWidth = 160;
    CGFloat hudHeight = 160;
	
	self.hudView.bounds = CGRectMake(0, 0, hudWidth, hudHeight);
	
    if(!string)
        self.imageView.center = CGPointMake(self.hudView.bounds.size.width/2, self.hudView.bounds.size.height/2);
    else
        self.imageView.center = CGPointMake(self.hudView.bounds.size.width/2, 70);
	
	self.stringLabel.hidden = NO;
	self.stringLabel.text = string;
}


- (void)showWithImage:(UIImage *)image status:(NSString *)string duration:(NSTimeInterval)duration {
	
	self.imageView.image = image;
    
	[self setStatus:string];
    [self.overlayWindow makeKeyAndVisible];
    [self positionHUD:nil];
    
    // Add the motion effect
    UIInterpolatingMotionEffect *imageMotionEffectH = [[UIInterpolatingMotionEffect alloc] initWithKeyPath:@"center.x" type:UIInterpolatingMotionEffectTypeTiltAlongHorizontalAxis];
    imageMotionEffectH.minimumRelativeValue = @(MOTION_EFFECT_MULTIPLIER);
    imageMotionEffectH.maximumRelativeValue = @(-MOTION_EFFECT_MULTIPLIER);
    
    UIInterpolatingMotionEffect *imageMotionEffectV = [[UIInterpolatingMotionEffect alloc] initWithKeyPath:@"center.y" type:UIInterpolatingMotionEffectTypeTiltAlongVerticalAxis];
    imageMotionEffectV.minimumRelativeValue = @(-MOTION_EFFECT_MULTIPLIER);
    imageMotionEffectV.maximumRelativeValue = @(MOTION_EFFECT_MULTIPLIER);
    
    UIMotionEffectGroup *imageMotionEffectGroup = [UIMotionEffectGroup new];
    imageMotionEffectGroup.motionEffects = @[imageMotionEffectH, imageMotionEffectV];
    [self.hudView addMotionEffect:imageMotionEffectGroup];
    
	if(self.alpha != 1) {
        [self registerNotifications];
		self.alpha = 1;
	}
    
    if(fadeOutTimer != nil)
		[fadeOutTimer invalidate], fadeOutTimer = nil;
	
	fadeOutTimer = [NSTimer scheduledTimerWithTimeInterval:duration target:self selector:@selector(dismiss) userInfo:nil repeats:NO];
    
    [self setNeedsDisplay];
}


- (void)registerNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(positionHUD:) 
                                                 name:UIApplicationDidChangeStatusBarOrientationNotification 
                                               object:nil];  
}


- (void)positionHUD:(NSNotification*)notification {
    double animationDuration = 0.2f;
    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
    CGRect orientationFrame = [UIScreen mainScreen].bounds;
    
    if(UIInterfaceOrientationIsLandscape(orientation)) {
        float temp = orientationFrame.size.width;
        orientationFrame.size.width = orientationFrame.size.height;
        orientationFrame.size.height = temp;
    }
    
    CGFloat activeHeight = orientationFrame.size.height;
    
    CGFloat posY = floor(activeHeight*0.52);
    CGFloat posX = orientationFrame.size.width/2;
    
    CGPoint newCenter;
    CGFloat rotateAngle;
    
    switch (orientation) { 
        case UIInterfaceOrientationPortraitUpsideDown:
            rotateAngle = M_PI; 
            newCenter = CGPointMake(posX, orientationFrame.size.height-posY);
            break;
        case UIInterfaceOrientationLandscapeLeft:
            rotateAngle = -M_PI/2.0f;
            newCenter = CGPointMake(posY, posX);
            break;
        case UIInterfaceOrientationLandscapeRight:
            rotateAngle = M_PI/2.0f;
            newCenter = CGPointMake(orientationFrame.size.height-posY, posX);
            break;
        default: // as UIInterfaceOrientationPortrait
            rotateAngle = 0.0;
            newCenter = CGPointMake(posX, posY);
            break;
    } 
    
    if(notification) {
        [UIView animateWithDuration:animationDuration
                              delay:0
                            options:UIViewAnimationOptionAllowUserInteraction
                         animations:^{
                             [self moveToPoint:newCenter rotateAngle:rotateAngle];
                         } completion:^(BOOL finished) {
                             [self updateBackdropImage:rotateAngle];
                         }];
    }
    
    else {
        [self moveToPoint:newCenter rotateAngle:rotateAngle];
        [self updateBackdropImage:rotateAngle];
    }
}

- (void)moveToPoint:(CGPoint)newCenter rotateAngle:(CGFloat)angle {
    self.hudView.transform = CGAffineTransformMakeRotation(angle);
    self.hudView.center = newCenter;
}

- (void)updateBackdropImage:(CGFloat)angle
{
    if (![self iOS7Style])
        return;
    
    UIWindow* mainWindow = [[UIApplication sharedApplication].delegate window];
    UIGraphicsBeginImageContextWithOptions(mainWindow.frame.size, YES, 0.0);
    CGContextSetInterpolationQuality(UIGraphicsGetCurrentContext(), kCGInterpolationHigh);
    [mainWindow drawViewHierarchyInRect:mainWindow.frame afterScreenUpdates:YES];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    UIImage *snapshot = image;
    
    CGFloat scale = [UIScreen mainScreen].scale;
    CGRect frame = CGRectMake(self.hudView.frame.origin.x * scale,
                              self.hudView.frame.origin.y * scale,
                              self.hudView.frame.size.width * scale,
                              self.hudView.frame.size.height * scale);
    
    CGImageRef imageRef = CGImageCreateWithImageInRect([snapshot CGImage], frame);
    UIImage* croppedSnapshot = [[UIImage imageWithCGImage:imageRef scale:scale orientation:UIImageOrientationUp] imageRotatedByRadians:-angle];
    CGImageRelease(imageRef);
    
    UIImage* blurredSnapshot = [croppedSnapshot applyBlurWithRadius:5 tintColor:[UIColor colorWithWhite:0.97 alpha:0.82] saturationDeltaFactor:1.8 maskImage:nil];
    
    self.hudView.image = blurredSnapshot;
    self.hudView.layer.cornerRadius = SVStatusHUDRingRadius;
    self.hudView.layer.masksToBounds = YES;
}

- (void)dismiss {
	
	[UIView animateWithDuration:SVStatusHUDFadeOutDuration
						  delay:0
						options:UIViewAnimationCurveEaseIn | UIViewAnimationOptionAllowUserInteraction
					 animations:^{	
						 sharedView.alpha = 0;
					 }
					 completion:^(BOOL finished){ 
                         if(sharedView.alpha == 0) {
                             [[NSNotificationCenter defaultCenter] removeObserver:sharedView];
                             overlayWindow = nil;
                             sharedView = nil;
                             
                             [[UIApplication sharedApplication].windows.lastObject makeKeyAndVisible];
                             
                             [[NSNotificationCenter defaultCenter] postNotificationName:SVStatusHUDDidFinishNotification
                                                                                 object:nil];
                             // uncomment to make sure UIWindow is gone from app.windows
                             //NSLog(@"%@", [UIApplication sharedApplication].windows);
                         }
                     }];
}

#pragma mark - Getters

- (UIWindow *)overlayWindow {
    if(!overlayWindow) {
        overlayWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        overlayWindow.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        overlayWindow.backgroundColor = [UIColor clearColor];
        overlayWindow.userInteractionEnabled = NO;
    }
    return overlayWindow;
}

- (UIView *)hudView {
    if(!hudView) {
        hudView = [[UIImageView alloc] initWithFrame:CGRectZero];
        hudView.layer.cornerRadius = SVStatusHUDRingRadius;
		hudView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];
        hudView.autoresizingMask = (UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleTopMargin |
                                    UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleLeftMargin);
        
        [self addSubview:hudView];
    }
    return hudView;
}

- (UILabel *)stringLabel {
    if (stringLabel == nil) {
        stringLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 123, 160, 20)];
		stringLabel.textColor = [self iOS7Style] ? [UIColor blackColor] : [UIColor whiteColor];
		stringLabel.backgroundColor = [UIColor clearColor];
		stringLabel.adjustsFontSizeToFitWidth = YES;
		stringLabel.textAlignment = NSTextAlignmentCenter;
		stringLabel.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
		stringLabel.font = [UIFont boldSystemFontOfSize:16];
        
        if (![self iOS7Style]) {
            stringLabel.shadowColor = [UIColor colorWithWhite:0 alpha:0.7];
            stringLabel.shadowOffset = CGSizeMake(1, 1);
        }
        stringLabel.numberOfLines = 0;
		[self.hudView addSubview:stringLabel];
    }
    return stringLabel;
}

- (SVStatusImage *)imageView {
    if (imageView == nil) {
        imageView = [[SVStatusImage alloc] initWithFrame:CGRectMake(0, 0, 86, 86)];
        imageView.backgroundColor = [UIColor clearColor];
        
        if (![self iOS7Style]) {
            imageView.layer.shadowColor = [UIColor blackColor].CGColor;
            imageView.layer.shadowRadius = 1;
            imageView.layer.shadowOpacity = 0.5;
            imageView.layer.shadowOffset = CGSizeMake(0, 1);
        }
		[self.hudView addSubview:imageView];
    }
    return imageView;
}

@end

@implementation SVStatusImage

@synthesize image;

- (void)drawRect:(CGRect)rect {
    CGRect bounds = self.bounds;
    BOOL iOS7 = [[[UIApplication sharedApplication].delegate window] respondsToSelector:@selector(drawViewHierarchyInRect:afterScreenUpdates:)];
    
    if (iOS7) {
        [[UIColor blackColor] set];
    }
    else {
        [[UIColor whiteColor] set];
    }
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(context, 0, self.frame.size.height);
    CGContextScaleCTM(context, 1.0, -1.0);
    CGContextClipToMask(context, bounds, [self.image CGImage]);
    CGContextFillRect(context, bounds);
}

- (void)setImage:(UIImage *)newImage {
    
    if(image)
        image = nil;
    
    if(newImage) {
        image = newImage;
        [self setNeedsDisplay];
    }
}

@end
