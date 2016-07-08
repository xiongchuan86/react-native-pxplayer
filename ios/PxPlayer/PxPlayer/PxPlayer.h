#import "RCTView.h"


#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#include "playerxx.h"
#include "tbox/tbox.h"

@class RCTEventDispatcher;

@interface PxPlayer : UIView

@property (assign, nonatomic) px_instance_t* pxInstance;
@property (nonatomic, readonly) int sourceWidth, sourceHeight;
@property (nonatomic) int outputWidth, outputHeight;
@property (nonatomic, readonly) double duration;
@property (nonatomic, readonly) double currentTime;
@property (nonatomic) BOOL paused;
@property (nonatomic) BOOL canPlay;
@property (nonatomic) BOOL playing;

@property (nonatomic, retain) RCTEventDispatcher *_eventDispatcher;
@property (nonatomic, retain) NSTimer *nextFrameTimer;

@property (nonatomic, retain) UIView *videoView;
@property (nonatomic, retain) UIImageView *imageView;

-(BOOL)setDataSource:(NSString*)uri useTcp:(BOOL)useTcp;
-(void)start;
-(void)stop;
-(void)pause;
-(void)setDisplay:(UIView*)videoView width:(int)width height:(int)height;
-(void)savePicture:(NSString*)path;

- (instancetype)initWithEventDispatcher:(RCTEventDispatcher *)eventDispatcher NS_DESIGNATED_INITIALIZER;

@end