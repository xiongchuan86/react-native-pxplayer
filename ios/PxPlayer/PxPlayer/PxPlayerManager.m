#import "PxPlayerManager.h"
#import "PxPlayer.h"
#import "RCTBridge.h"

@implementation PxPlayerManager

RCT_EXPORT_MODULE();

@synthesize bridge = _bridge;

- (UIView *)view
{
  return [[PxPlayer alloc] initWithEventDispatcher:self.bridge.eventDispatcher];
}

/* Should support: onLoadStart, onLoad, and onError to stay consistent with Image */

- (NSArray *)customDirectEventTypes
{
  return @[
    @"onVideoStartPlay",
    @"onVideoBuffering",
    @"onVideoPlaying",
    @"onVideoPaused",
    @"onVideoStopped",
    @"onVideoError"
  ];
}

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}

RCT_EXPORT_VIEW_PROPERTY(source, NSDictionary);
RCT_EXPORT_VIEW_PROPERTY(paused, BOOL);
RCT_EXPORT_VIEW_PROPERTY(snapshotPath, NSString);


@end
