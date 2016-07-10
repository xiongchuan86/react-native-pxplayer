#import <UIKit/UIKit.h>

@interface KNGLView : UIView
@property (retain, nonatomic) EAGLContext* context;
- (void)render:(NSDictionary *)frameData;
@end