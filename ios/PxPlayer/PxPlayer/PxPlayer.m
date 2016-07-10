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

@synthesize glView = _glView;
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
    //if(_nextFrameTimer.isValid)return;
    if(_pxInstance){
        _playing = YES;
        [self displayNextFrame];
//        _nextFrameTimer = [NSTimer scheduledTimerWithTimeInterval:1.0/25
//                                                               target:self
//                                                               selector:@selector(displayNextFrame:)
//                                                               userInfo:nil
//                                                               repeats:YES];
        [self playerStateChanged:PLAYER_STATE_START];
    }
}

-(void)stop
{
    if(!_canPlay)return;
//    if(_nextFrameTimer.isValid)
//        [_nextFrameTimer invalidate];
//    _nextFrameTimer = nil;
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
    outputHeight = height;
    outputWidth  = width;
    
    _videoView = videoView;
    NSArray *viewsToRemove = [_videoView subviews];
    for (UIView *v in viewsToRemove) {
        [v removeFromSuperview];
    }
    
    if(_useGLView){
        [self initGLView];
    }else{
        [self initImageView];
    }
    
    px_setOutputSize(_pxInstance,width,height);
}

-(void)initGLView
{
    _glView = [[KNGLView alloc] initWithFrame:CGRectMake(0, 0, outputWidth, outputHeight)];
    _glView.contentMode = UIViewContentModeScaleAspectFit;
    [_videoView addSubview:_glView];//add opengl view
}

-(void)initImageView
{
    _imageView=[[UIImageView alloc] initWithFrame:CGRectMake(0, 0, outputWidth, outputHeight)];
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
        [self setTransform:transform];
        if(_useGLView){
            [_glView setFrame:CGRectMake(0, 0, height, width)];
        }else{
            [_imageView setFrame:CGRectMake(0, 0, height, width)];
        }
        
    }else if(isFull == NO && _fullscreen == YES){
        _fullscreen = NO;
        CGAffineTransform transform = CGAffineTransformMakeRotation( 0);
        [self setTransform:transform];
        if(_useGLView){
            [_glView setFrame:CGRectMake(0, 0, outputWidth, outputHeight)];
        }else{
            [_imageView setFrame:CGRectMake(0, 0, outputWidth, outputHeight)];
        }
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

-(void)displayNextFrame
{
    if(_paused)return;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//        @synchronized(_pxInstance){
//            
//        }
        while(1){
            if(_paused)break;
            @autoreleasepool {
                if( _pxInstance && px_stepFrame(_pxInstance)){
                    [self playerStateChanged:PLAYER_STATE_PLAYING];
                    if(_useGLView){
                        //render frame for opengl
                        NSDictionary* frameData = [self makeFrameData];
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [_glView render:frameData];
                            av_free_packet(&_pxInstance->packet);
                        });
                    }else{
                        px_convertFrameToRGB(_pxInstance);
                        dispatch_async(dispatch_get_main_queue(), ^{
                            _imageView.image = [self imageFromAVPicture:_pxInstance->picture width:outputWidth height:outputHeight];
                            av_free_packet(&_pxInstance->packet);
                        });
                    }
                    
                }else{
                    [self playerStateChanged:PLAYER_STATE_BUFFERING];
                    break;
                }
            }
        }//end while for read frame
        //exit thread
    });
}

- (NSDictionary *)makeFrameData {
    
    NSMutableDictionary* frameData = [NSMutableDictionary dictionary];
    [frameData setObject:[NSNumber numberWithInt:_pxInstance->pCodecCtx->width] forKey:@"width"];
    [frameData setObject:[NSNumber numberWithInt:_pxInstance->pCodecCtx->height] forKey:@"height"];
    //NSLog(@"make framedata y width=%i,linesize=%i",_pxInstance->pCodecCtx->width,_pxInstance->pFrame->linesize[0]);
    NSData* ydata = [self copYUVData:_pxInstance->pFrame->data[0] linesize:_pxInstance->pFrame->linesize[0] width:_pxInstance->pCodecCtx->width height:_pxInstance->pCodecCtx->height];
    NSData* udata = [self copYUVData:_pxInstance->pFrame->data[1] linesize:_pxInstance->pFrame->linesize[1] width:_pxInstance->pCodecCtx->width/2 height:_pxInstance->pCodecCtx->height/2];
    NSData* vdata = [self copYUVData:_pxInstance->pFrame->data[2] linesize:_pxInstance->pFrame->linesize[2] width:_pxInstance->pCodecCtx->width/2 height:_pxInstance->pCodecCtx->height/2];
    [frameData setObject:ydata forKey:@"Y"];
    [frameData setObject:udata forKey:@"U"];
    [frameData setObject:vdata forKey:@"V"];
    
    return frameData;
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
