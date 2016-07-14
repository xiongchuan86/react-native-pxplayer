#import "RCTView.h"
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#include "tbox/tbox.h"
#import "RTSPPlayer.h"
#import "Utilities.h"

@class RCTEventDispatcher;

@interface PxPlayer : UIView


typedef enum {
    PLAYER_STATE_START,
    PLAYER_STATE_BUFFERING,
    PLAYER_STATE_PLAYING,
    PLAYER_STATE_PAUSED,
    PLAYER_STATE_STOPPED,
    PLAYER_STATE_ERROR
}playerState;

@property (nonatomic, readonly) int sourceWidth, sourceHeight;
@property (nonatomic) int outputWidth, outputHeight;
@property (nonatomic, readonly) double duration;
@property (nonatomic, readonly) double currentTime;
@property (nonatomic) BOOL paused;
@property (nonatomic) BOOL canPlay;
@property (nonatomic) BOOL playing;
@property (nonatomic) BOOL fullscreen;

@property (nonatomic) BOOL useGLView;
@property (nonatomic) BOOL releaseInstance;

@property (nonatomic, retain) NSString *errorMsg;
@property (nonatomic, retain) RCTEventDispatcher *_eventDispatcher;
@property (nonatomic, retain) NSTimer *nextFrameTimer;

@property (nonatomic, retain) UIView *videoView;
@property (nonatomic, retain) UIImageView *imageView;

@property (nonatomic, retain) RTSPPlayer *video;



-(void)start;
-(void)stop;
-(void)pause;
-(void)setDisplay:(UIView*)videoView width:(int)width height:(int)height;
-(void)savePicture:(NSString*)path;
- (instancetype)initWithEventDispatcher:(RCTEventDispatcher *)eventDispatcher NS_DESIGNATED_INITIALIZER;

@end
