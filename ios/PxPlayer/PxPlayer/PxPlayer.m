//
//  Playerxx.m
//  playerxx
//
//  Created by 熊川 on 16/7/5.
//  Copyright © 2016年 熊川. All rights reserved.
//
#import "RCTConvert.h"
#import "RCTBridgeModule.h"
#import "RCTEventDispatcher.h"
#import "UIView+React.h"
#import "PxPlayer.h"

@implementation PxPlayer

@synthesize outputWidth, outputHeight , video;

@synthesize nextFrameTimer = _nextFrameTimer;

///////////////////

- (instancetype)initWithEventDispatcher:(RCTEventDispatcher *)eventDispatcher
{
    if ((self = [super init])) {
        self._eventDispatcher = eventDispatcher;

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillResignActive:)
                                                     name:UIApplicationWillResignActiveNotification
                                                   object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillEnterForeground:)
                                                     name:UIApplicationWillEnterForegroundNotification
                                                   object:nil];

    }
    _canPlay = NO;
    _paused  = NO;
    _errorMsg = @"";
    _useGLView = NO;
    _releaseInstance = NO;
    outputHeight = 0;
    outputWidth  = 0;

    
    return self;
}

- (void)applicationWillResignActive:(NSNotification *)notification
{
    if (!_paused) {
        [self setPaused:_paused];
    }
}

- (void)applicationWillEnterForeground:(NSNotification *)notification
{

}

- (BOOL) isBlankString:(NSString *)string {
    if (string == nil || string == NULL) {
        return YES;
    }
    if ([string isKindOfClass:[NSNull class]]) {
        return YES;
    }
    if ([[string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] length]==0) {
        return YES;
    }
    return NO;
}

-(void)setSource:(NSDictionary *)source
{
    
    if(video){
        video = nil;
        [self stop];
    }
    
    NSString* uri    = [source objectForKey:@"uri"];
    BOOL    useTcp   = [RCTConvert BOOL:[source objectForKey:@"useTcp"]];
    int     width    = [RCTConvert int:[source objectForKey:@"width"]];
    int     height   = [RCTConvert int:[source objectForKey:@"height"]];
    NSLog(@"width=%i,height=%i",width,height);
    if( ![self isBlankString:uri] ){
        [self setDataSource:uri useTcp:useTcp width:width height:height];
    }
 
}

-(void)setSnapshotPath:(NSString*)path
{
    if(video)
        [self savePicture:path];
}

- (void)setPaused:(BOOL)paused
{
    if(video){
        if(paused && _playing){
            [self pause];
        }
        if(_paused){
            [self playerStateChanged:PLAYER_STATE_PAUSED];
        }else{
            [self playerStateChanged:PLAYER_STATE_PLAYING];
        }
    }
}

/////////////////

-(void)setDataSource:(NSString*)uri useTcp:(BOOL)useTcp width:(int)width height:(int)height
{
    [self setDisplay:self width:width height:height];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        video = [[RTSPPlayer alloc] initWithVideo:uri usesTcp:useTcp];
        if(video == nil){
            _errorMsg = @"无法播放";
            [self playerStateChanged:PLAYER_STATE_ERROR];
        }else{
            NSLog(@"width=%i,height=%i",width,height);
            video.outputWidth  = width;
            video.outputHeight = height;
            dispatch_async(dispatch_get_main_queue(),^{
                [self start];
            });
        }
    });
}

-(void)start
{
    if(video){
        [_nextFrameTimer invalidate];
        _nextFrameTimer = [NSTimer scheduledTimerWithTimeInterval:1.0/30
                                                             target:self
                                                             selector:@selector(displayNextFrame)
                                                             userInfo:nil
                                                             repeats:YES];
        [self playerStateChanged:PLAYER_STATE_START];
    }
}

-(void)stop
{
    if(video){
        _playing = NO;
        [_nextFrameTimer invalidate];
        _nextFrameTimer = nil;
        [self playerStateChanged:PLAYER_STATE_STOPPED];
    }
}

-(void)pause
{
    if(video){
        _paused = !_paused;
    }
}

-(void)setDisplay:(UIView*)videoView width:(int)width height:(int)height
{
    outputWidth  = width;
    outputHeight = height;
    
    _videoView = videoView;
    NSArray *viewsToRemove = [_videoView subviews];
    for (UIView *v in viewsToRemove) {
        [v removeFromSuperview];
    }
    
    CGRect frame = CGRectMake(0, 0, width, height);
    
    if(_useGLView){
        [self initGLViewWith:frame];
    }else{
        [self initImageViewWith:frame];
    }
    
}

-(void)initGLViewWith:(CGRect)frame
{

}

-(void)initImageViewWith:(CGRect)frame
{
    _imageView=[[UIImageView alloc] initWithFrame:frame];
    [_imageView setContentMode:UIViewContentModeScaleAspectFill];
    [_videoView addSubview:_imageView];
}

-(void)setFullscreen:(BOOL)isFull
{
    CGRect screenBounds = [[UIScreen mainScreen] bounds];
    int width = (int)screenBounds.size.width;
    int height = (int)screenBounds.size.height;
    if(isFull && _fullscreen==NO){
        _fullscreen = YES;
        CGAffineTransform transform = CGAffineTransformMakeRotation(90 * M_PI/180.0);
        if(_useGLView){

        }else{
            [_imageView setTransform:transform];
            [_imageView setFrame:CGRectMake(0, 0, width,height)];
        }
    }else if(isFull == NO && _fullscreen == YES){
        _fullscreen = NO;
        CGAffineTransform transform = CGAffineTransformMakeRotation(0);
        if(_useGLView){

        }else{
            [_imageView setTransform:transform];
            [_imageView setFrame:CGRectMake(0, 0, outputWidth, outputHeight)];
        }
    }
}

-(void)setOutputWidth:(int)value
{
    outputWidth = value;
}

-(void)setOutputHeight:(int)value
{
    outputHeight = value;
}


- (UIImage *)imageFromAVPicture:(AVPicture)pict width:(int)width height:(int)height
{
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault;
    CFDataRef data = CFDataCreateWithBytesNoCopy(kCFAllocatorDefault, pict.data[0], pict.linesize[0]*height,kCFAllocatorNull);
    CGDataProviderRef provider = CGDataProviderCreateWithCFData(data);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGImageRef cgImage = CGImageCreate(width,
                                       height,
                                       8,
                                       24,
                                       pict.linesize[0],
                                       colorSpace,
                                       bitmapInfo,
                                       provider,
                                       NULL,
                                       NO,
                                       kCGRenderingIntentDefault);
    CGColorSpaceRelease(colorSpace);
    UIImage *image = [UIImage imageWithCGImage:cgImage];

    CGImageRelease(cgImage);
    CGDataProviderRelease(provider);
    CFRelease(data);

    return image;
}


- (void)playerStateChanged:(playerState)state
{
    switch (state) {
        case PLAYER_STATE_PAUSED:
            _paused = YES;
            //NSLog(@"VLCMediaPlayerStatePaused %i",VLCMediaPlayerStatePaused);
            [self._eventDispatcher sendInputEventWithName:@"onVideoPaused"
                                                body:@{
                                                       @"target": self.reactTag
                                                       }];
            break;
        case PLAYER_STATE_STOPPED:
            //NSLog(@"VLCMediaPlayerStateStopped %i",VLCMediaPlayerStateStopped);
            [self._eventDispatcher sendInputEventWithName:@"onVideoStopped"
                                                body:@{
                                                       @"target": self.reactTag
                                                       }];
            break;
        case PLAYER_STATE_START:
            _paused = NO;
            [self._eventDispatcher sendInputEventWithName:@"onVideoStartPlay"
                                                body:@{
                                                       @"target": self.reactTag
                                                       }];
            break;
        case PLAYER_STATE_BUFFERING:
            _paused = NO;
            [self._eventDispatcher sendInputEventWithName:@"onVideoBuffering"
                                                body:@{
                                                       @"target": self.reactTag
                                                       }];
            break;
        case PLAYER_STATE_PLAYING:
            _paused = NO;
            [self._eventDispatcher sendInputEventWithName:@"onVideoPlaying"
                                                body:@{
                                                       @"target": self.reactTag
                                                       }];
            break;
         case PLAYER_STATE_ERROR:
            [self._eventDispatcher sendInputEventWithName:@"onVideoError"
                                                body:@{
                                                       @"target": self.reactTag,
                                                       @"error":  self.errorMsg
                                                       }];
            [self _release];
            break;
        default:
            //NSLog(@"state %i",state);
            break;
    }
}

#define LERP(A,B,C) ((A)*(1.0-C)+(B)*C)

-(void)displayNextFrame
{
    if(video && _paused)return;//pause
    @autoreleasepool {
        if (![video stepFrame]) {
            [video closeAudio];
            return;
        }
        if(!_playing){
            _playing = YES;
            [self playerStateChanged:PLAYER_STATE_PLAYING];
        }
        [self playerStateChanged:PLAYER_STATE_PLAYING];
        _imageView.image = video.currentImage;
    }
}

- (NSData *)copYUVData:(UInt8 *)src linesize:(int)linesize width:(int)width height:(int)height {
    
    width = MIN(linesize, width);
    NSMutableData *md = [NSMutableData dataWithLength: width * height];
    Byte *dst = md.mutableBytes;
    for (NSUInteger i = 0; i < height; ++i) {
        memcpy(dst, src, width);
        dst += width;
        src += linesize;
    }
    return md;
}


- (void)_release
{
    if(video){
        [self pause];
        [self stop];
    }
}

-(void)savePicture:(NSString*)path
{
    //构建路径
    //    NSString *strPath = [[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"] stringByAppendingPathComponent:path];
    NSLog(@"path=%@",path);
    //保存png的图片到app下的Document/saveimg.png
    [UIImagePNGRepresentation(_imageView.image) writeToFile:path atomically:YES];
}

#pragma mark - Lifecycle
- (void)removeFromSuperview
{
    [self _release];
    [super removeFromSuperview];
}


@end
