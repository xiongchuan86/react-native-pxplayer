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

@synthesize outputWidth, outputHeight;

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
    [self setContentMode:UIViewContentModeScaleAspectFill];
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

-(void)setSource:(NSDictionary *)source
{

    NSString* uri    = [source objectForKey:@"uri"];
    BOOL    useTcp   = [RCTConvert BOOL:[source objectForKey:@"useTcp"]];
    int     width    = [RCTConvert int:[source objectForKey:@"width"]];
    int     height   = [RCTConvert int:[source objectForKey:@"height"]];

    BOOL canPlay = [self setDataSource:uri useTcp:useTcp];
    if(canPlay){
        [self setDisplay:self width:width height:height];
        [self start];
    }else{
        _errorMsg = @"无法播放";
        [self playerStateChanged:PLAYER_STATE_ERROR];
    }
}

-(void)setSnapshotPath:(NSString*)path
{
    if(_pxInstance)
        [self savePicture:path];
}

- (void)setPaused:(BOOL)paused
{
    if(_pxInstance && _canPlay){
        if(paused && _playing){
            [self pause];
        }
    }
    if(_paused){
        [self playerStateChanged:PLAYER_STATE_PAUSED];
    }else{
        [self playerStateChanged:PLAYER_STATE_PLAYING];
    }
}

/////////////////

-(BOOL)setDataSource:(NSString*)uri useTcp:(BOOL)useTcp
{
    _canPlay = NO;
    _pxInstance = px_initWithUri([uri cStringUsingEncoding:NSASCIIStringEncoding],useTcp);
    if(_pxInstance){
        //初始化outputwidth,outputheight
        outputHeight = _pxInstance->outputWidth;
        outputWidth  = _pxInstance->outputHeight;
        _canPlay = YES;
    }
    return _canPlay;
}

-(void)start
{
    if(!_canPlay)return;
    if(_nextFrameTimer.isValid)return;
    if(_pxInstance){
        _playing = YES;
        _nextFrameTimer = [NSTimer scheduledTimerWithTimeInterval:1.0/25
                                                               target:self
                                                               selector:@selector(displayNextFrame:)
                                                               userInfo:nil
                                                               repeats:YES];
        [self playerStateChanged:PLAYER_STATE_START];
    }
}

-(void)stop
{
    if(!_canPlay)return;
    if(_nextFrameTimer.isValid)
        [_nextFrameTimer invalidate];
    _nextFrameTimer = nil;
    _playing = NO;
    [self playerStateChanged:PLAYER_STATE_STOPPED];
}

-(void)pause
{
    if(!_canPlay)return;
    _paused = !_paused;
}

-(void)setDisplay:(UIView*)videoView width:(int)width height:(int)height
{
    if(!_canPlay)return;
    _videoView = videoView;
    NSArray *viewsToRemove = [_videoView subviews];
    for (UIView *v in viewsToRemove) {
        [v removeFromSuperview];
    }
    _imageView=[[UIImageView alloc] initWithFrame:CGRectMake(0, 0, width, height)];
    [_imageView setContentMode:UIViewContentModeScaleAspectFill];
    [_videoView addSubview:_imageView];
    outputHeight = height;
    outputWidth  = width;
    px_setOutputSize(_pxInstance,width,height);
}

-(void)setFullscreen:(BOOL)isFull
{
    CGRect screenBounds = [[UIScreen mainScreen] bounds];
    int width = (int)screenBounds.size.width;
    int height = (int)screenBounds.size.height;
    if(isFull && _fullscreen==NO){
        _fullscreen = YES;
        CGAffineTransform transform = CGAffineTransformMakeRotation(90 * M_PI/180.0);
        [self setTransform:transform];
        [_imageView setFrame:CGRectMake(0, 0, height, width)];
    }else if(isFull == NO && _fullscreen == YES){
        _fullscreen = NO;
        CGAffineTransform transform = CGAffineTransformMakeRotation( 0);
        [self setTransform:transform];
        [_imageView setFrame:CGRectMake(0, 0, outputWidth, outputHeight)];
    }
    
}


-(int)sourceWidth
{
    if(!_canPlay)return 0;
    return _pxInstance->pCodecCtx->width;
}

-(int)sourceHeight
{
    if(!_canPlay)return 0;
    return _pxInstance->pCodecCtx->height;
}

-(void)setOutputWidth:(int)value
{
    outputWidth = value;
}

-(void)setOutputHeight:(int)value
{
    outputHeight = value;
}


-(double)duration
{
    if(!_canPlay)return 0;
    return (double)_pxInstance->pFormatCtx->duration / AV_TIME_BASE;
}


-(double)currentTime
{
    if(!_canPlay)return 0;
    AVRational timeBase = _pxInstance->pFormatCtx->streams[_pxInstance->videoStream]->time_base;
    return _pxInstance->packet.pts * (double)timeBase.num / timeBase.den;
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

-(void)displayNextFrame:(NSTimer *)timer
{
    if(_paused)return;
    dispatch_async(dispatch_get_main_queue(), ^{
        if(px_stepFrame(_pxInstance)){
            [self playerStateChanged:PLAYER_STATE_PLAYING];
            px_convertFrameToRGB(_pxInstance);
            _imageView.image = [self imageFromAVPicture:_pxInstance->picture width:outputWidth height:outputHeight];
        }else{
            [self playerStateChanged:PLAYER_STATE_BUFFERING];
        }
    });
    
}


- (void)_release
{
    if(_pxInstance){
        [self stop];
        // Free scaler
        if(_pxInstance->img_convert_ctx)sws_freeContext(_pxInstance->img_convert_ctx);

        // Free RGB picture
        avpicture_free(&_pxInstance->picture);

        // Free the packet that was allocated by av_read_frame
        av_free_packet(&_pxInstance->packet);

        // Free the YUV frame
        if(_pxInstance->pFrame)av_free(_pxInstance->pFrame);

        // Close the codec
        if (_pxInstance->pCodecCtx) avcodec_close(_pxInstance->pCodecCtx);

        // Close the video file
        if (_pxInstance->pFormatCtx) avformat_close_input(&_pxInstance->pFormatCtx);
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
