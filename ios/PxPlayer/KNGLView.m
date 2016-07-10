#import "KNGLView.h"
#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/EAGLDrawable.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>

enum {
    ATTRIBUTE_VERTEX,
   	ATTRIBUTE_TEXCOORD,
};

//_________________________________________________________________SHADER
#pragma mark - SHADER
#define STRINGIZE(x) #x
#define STRINGIZE2(x) STRINGIZE(x)
#define SHADER_STRING(text) @ STRINGIZE2(text)

NSString *const vertexShaderString = SHADER_STRING
(
 attribute vec4 position;
 attribute vec2 texcoord;
 uniform mat4 modelViewProjectionMatrix;
 varying vec2 v_texcoord;
 
 void main()
 {
     gl_Position = modelViewProjectionMatrix * position;
     v_texcoord = texcoord.xy;
 }
 );


NSString *const yuvFragmentShaderString = SHADER_STRING
(
 varying highp vec2 v_texcoord;
 uniform sampler2D s_texture_y;
 uniform sampler2D s_texture_u;
 uniform sampler2D s_texture_v;
 
 void main()
 {
     highp float y = texture2D(s_texture_y, v_texcoord).r;
     highp float u = texture2D(s_texture_u, v_texcoord).r - 0.5;
     highp float v = texture2D(s_texture_v, v_texcoord).r - 0.5;
     
     highp float r = y +             1.402 * v;
     highp float g = y - 0.344 * u - 0.714 * v;
     highp float b = y + 1.772 * u;
     
     gl_FragColor = vec4(r,g,b,1.0);
 }
 );

static BOOL validateProgram(GLuint prog)
{
    GLint status;
    
    glValidateProgram(prog);
    
#ifdef DEBUG
    GLint logLength;
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0)
    {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program validate log:\n%s", log);
        free(log);
    }
#endif
    
    glGetProgramiv(prog, GL_VALIDATE_STATUS, &status);
    if (status == GL_FALSE) {
        NSLog(@"Failed to validate program %d", prog);
        return NO;
    }
    
    return YES;
}

static GLuint compileShader(GLenum type, NSString *shaderString)
{
    GLint status;
    const GLchar *sources = (GLchar *)shaderString.UTF8String;
    
    GLuint shader = glCreateShader(type);
    if (shader == 0 || shader == GL_INVALID_ENUM) {
        NSLog(@"Failed to create shader %d", type);
        return 0;
    }
    
    glShaderSource(shader, 1, &sources, NULL);
    glCompileShader(shader);
    
#ifdef DEBUG
    GLint logLength;
    glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0)
    {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetShaderInfoLog(shader, logLength, &logLength, log);
        NSLog(@"Shader compile log:\n%s", log);
        free(log);
    }
#endif
    
    glGetShaderiv(shader, GL_COMPILE_STATUS, &status);
    if (status == GL_FALSE) {
        glDeleteShader(shader);
        NSLog(@"Failed to compile shader:\n");
        return 0;
    }
    
    return shader;
}

static void mat4f_LoadOrtho(float left, float right, float bottom, float top, float near, float far, float* mout)
{
    float r_l = right - left;
    float t_b = top - bottom;
    float f_n = far - near;
    float tx = - (right + left) / (right - left);
    float ty = - (top + bottom) / (top - bottom);
    float tz = - (far + near) / (far - near);
    
    mout[0] = 2.0f / r_l;
    mout[1] = 0.0f;
    mout[2] = 0.0f;
    mout[3] = 0.0f;
    
    mout[4] = 0.0f;
    mout[5] = 2.0f / t_b;
    mout[6] = 0.0f;
    mout[7] = 0.0f;
    
    mout[8] = 0.0f;
    mout[9] = 0.0f;
    mout[10] = -2.0f / f_n;
    mout[11] = 0.0f;
    
    mout[12] = tx;
    mout[13] = ty;
    mout[14] = tz;
    mout[15] = 1.0f;
}
//_________________________________________________________________SHADER



@interface KNGLView () {
    
    GLuint          framebuffer_;
    GLuint          renderbuffer_;
    GLint           backingWidth_;
    GLint           backingHeight_;
    
    GLuint          program_;
    GLint           uniformMatrix_;
    GLfloat         vertices_[8];
    
    GLint           uniformSamplers_[3];
    GLuint          textures_[3];
    
    CGSize          frameSize_;
}
- (void)setupLayer;
- (BOOL)setupContext;
- (void)setupRenderBuffer;
- (BOOL)setupFrameBuffer;
- (BOOL)loadShaders;
- (void)updateVertices;
- (void)makeTexture:(NSDictionary *)frameData;
- (BOOL)prepareRender;
@end


@implementation KNGLView

@synthesize context = _context;


#pragma mark - VIEW CYCLE
- (void)dealloc {
    
    if (framebuffer_) {
        glDeleteFramebuffers(1, &framebuffer_);
        framebuffer_ = 0;
    }
    
    if (renderbuffer_) {
        glDeleteRenderbuffers(1, &renderbuffer_);
        renderbuffer_ = 0;
    }
    
    if (program_) {
        glDeleteProgram(program_);
        program_ = 0;
    }
    
    if ([EAGLContext currentContext] == _context) {
        [EAGLContext setCurrentContext:nil];
    }
    
    _context = nil;
    
    if (textures_[0])
        glDeleteTextures(3, textures_);
    
}

+ (Class)layerClass {
    return [CAEAGLLayer class];
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        
        [self setupLayer];
        
        if ([self setupContext] == NO)
            return nil;
        
        [self setupRenderBuffer];
        
        if ([self setupFrameBuffer] == NO)
            return nil;
        
        GLenum glError = glGetError();
        if (GL_NO_ERROR != glError) {
            NSLog(@"failed to setup GL %x", glError);
            return nil;
        }
        
        if ([self loadShaders] == NO)
            return nil;
        
        vertices_[0] = -1.0f;  // x0
        vertices_[1] = -1.0f;  // y0
        vertices_[2] =  1.0f;  // ..
        vertices_[3] = -1.0f;
        vertices_[4] = -1.0f;
        vertices_[5] =  1.0f;
        vertices_[6] =  1.0f;  // x3
        vertices_[7] =  1.0f;  // y3
        
        NSLog(@"OK setup GL");
    }
    return self;
}

- (void)layoutSubviews
{
    glBindRenderbuffer(GL_RENDERBUFFER, renderbuffer_);
    [_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer*)self.layer];
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &backingWidth_);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &backingHeight_);
    
    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if (status != GL_FRAMEBUFFER_COMPLETE) {
        NSLog(@"failed to make complete framebuffer object %x", status);
    } else {
        NSLog(@"OK setup GL framebuffer %d:%d", backingWidth_, backingHeight_);
    }
    
    [self updateVertices];
    [self render: nil];
}

- (void)setContentMode:(UIViewContentMode)contentMode
{
    [super setContentMode:contentMode];
    [self updateVertices];
}

#pragma mark - PRIVATE
- (void)setupLayer {
    CAEAGLLayer *eaglLayer = (CAEAGLLayer*)self.layer;
    eaglLayer.opaque = YES;
    eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithBool:FALSE], kEAGLDrawablePropertyRetainedBacking,
                                    kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat,
                                    nil];
}

- (BOOL)setupContext {
    _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    
    if (!_context || ![EAGLContext setCurrentContext:_context]) {
        NSLog(@"failed to setup EAGLContext");
        return NO;
    }
    return YES;
}

- (void)setupRenderBuffer {
    glGenRenderbuffers(1, &renderbuffer_);
    glBindRenderbuffer(GL_RENDERBUFFER, renderbuffer_);
    [_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer*)self.layer];
    
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &backingWidth_);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &backingHeight_);
    
    NSLog(@"Backing Width : %d, Height :%d", backingWidth_, backingHeight_);
}

- (BOOL)setupFrameBuffer {
    glGenFramebuffers(1, &framebuffer_);
    glBindFramebuffer(GL_FRAMEBUFFER, framebuffer_);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, renderbuffer_);
    
    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if (status != GL_FRAMEBUFFER_COMPLETE) {
        
        NSLog(@"failed to make complete framebuffer object %x", status);
        return NO;
    }
    return YES;
}

- (BOOL)loadShaders {
    
    BOOL result = NO;
    GLuint vertShader = 0, fragShader = 0;
    
    program_ = glCreateProgram();
    
    vertShader = compileShader(GL_VERTEX_SHADER, vertexShaderString);
    if (!vertShader)
        goto exit;
    
    fragShader = compileShader(GL_FRAGMENT_SHADER, yuvFragmentShaderString);
    if (!fragShader)
        goto exit;
    
    glAttachShader(program_, vertShader);
    glAttachShader(program_, fragShader);
    glBindAttribLocation(program_, ATTRIBUTE_VERTEX, "position");
    glBindAttribLocation(program_, ATTRIBUTE_TEXCOORD, "texcoord");
    
    glLinkProgram(program_);
    
    GLint status;
    glGetProgramiv(program_, GL_LINK_STATUS, &status);
    if (status == GL_FALSE) {
        NSLog(@"Failed to link program %d", program_);
        goto exit;
    }
    result = validateProgram(program_);
    
    uniformMatrix_ = glGetUniformLocation(program_, "modelViewProjectionMatrix");
    uniformSamplers_[0] = glGetUniformLocation(program_, "s_texture_y");
    uniformSamplers_[1] = glGetUniformLocation(program_, "s_texture_u");
    uniformSamplers_[2] = glGetUniformLocation(program_, "s_texture_v");
    
exit:
    if (vertShader)
        glDeleteShader(vertShader);
    if (fragShader)
        glDeleteShader(fragShader);
    
    if (result) {
        NSLog(@"OK setup GL programm");
    } else {
        glDeleteProgram(program_);
        program_ = 0;
    }
    return result;
}

- (void)updateVertices {
    
    const BOOL fit      = (self.contentMode == UIViewContentModeScaleAspectFit);
    const float width   = frameSize_.width;
    const float height  = frameSize_.height;
    const float dH      = (float)backingHeight_ / height;
    const float dW      = (float)backingWidth_	  / width;
    const float dd      = fit ? MIN(dH, dW) : MAX(dH, dW);
    float h             = (height * dd / (float)backingHeight_);
    float w             = (width  * dd / (float)backingWidth_ );
    
    if (fit == NO)
        w = h = 1;
    
    vertices_[0] = - w;
    vertices_[1] = - h;
    vertices_[2] =   w;
    vertices_[3] = - h;
    vertices_[4] = - w;
    vertices_[5] =   h;
    vertices_[6] =   w;
    vertices_[7] =   h;
    
    NSLog(@"Vertices w:%.0f h:%.0f", w, h);
}

- (void)makeTexture:(NSDictionary *)frameData {
    
    NSInteger width     = [[frameData objectForKey:@"width"] integerValue];
    NSInteger height    = [[frameData objectForKey:@"height"] integerValue];
    NSData* Y        = [frameData objectForKey:@"Y"];
    NSData* U     = [frameData objectForKey:@"U"];
    NSData* V     = [frameData objectForKey:@"V"];
    
    CGSize frameSize = CGSizeMake(width, height);
    if ((CGSizeEqualToSize(frameSize_, frameSize) == NO)) {
        frameSize_ = frameSize;
        [self updateVertices];
    }
    //NSLog(@"Y.length=%i",Y.length);
    //NSLog(@"width=%i,height=%i,==%i",width,height,width*height);
//    
//    assert(luma.length == width * height);
//    assert(chromaB.length == (width * height) / 4);
//    assert(chromaR.length == (width * height) / 4);
    
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    
    if (0 == textures_[0])
        glGenTextures(3, textures_);
    
    const UInt8 *pixels[3] = { Y.bytes, U.bytes, V.bytes };
    const NSUInteger widths[3]  = { width, width / 2, width / 2 };
    const NSUInteger heights[3] = { height, height / 2, height / 2 };
    
    for (int i = 0; i < 3; ++i) {
        
        glBindTexture(GL_TEXTURE_2D, textures_[i]);
        
        glTexImage2D(GL_TEXTURE_2D,
                     0,
                     GL_LUMINANCE,
                     widths[i],
                     heights[i],
                     0,
                     GL_LUMINANCE,
                     GL_UNSIGNED_BYTE,
                     pixels[i]);
        
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    }
}


- (BOOL)prepareRender
{
    if (textures_[0] == 0)
        return NO;
    
    for (int i = 0; i < 3; ++i) {
        glActiveTexture(GL_TEXTURE0 + i);
        glBindTexture(GL_TEXTURE_2D, textures_[i]);
        glUniform1i(uniformSamplers_[i], i);
    }
    return YES;
}
#pragma mark - PUBLIC

- (void)render:(NSDictionary *)frameData {
    
    static const GLfloat texCoords[] = {
        0.0f, 1.0f,
        1.0f, 1.0f,
        0.0f, 0.0f,
        1.0f, 0.0f,
    };
    
    [EAGLContext setCurrentContext:_context];
    
    glBindFramebuffer(GL_FRAMEBUFFER, framebuffer_);
    glViewport(0, 0, backingWidth_, backingHeight_);
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    glUseProgram(program_);
    
    if (frameData) {
        [self makeTexture:frameData];
    }
    
    if ([self prepareRender]) {
        
        GLfloat modelviewProj[16];
        mat4f_LoadOrtho(-1.0f, 1.0f, -1.0f, 1.0f, -1.0f, 1.0f, modelviewProj);
        glUniformMatrix4fv(uniformMatrix_, 1, GL_FALSE, modelviewProj);
        
        glVertexAttribPointer(ATTRIBUTE_VERTEX, 2, GL_FLOAT, 0, 0, vertices_);
        glEnableVertexAttribArray(ATTRIBUTE_VERTEX);
        glVertexAttribPointer(ATTRIBUTE_TEXCOORD, 2, GL_FLOAT, 0, 0, texCoords);
        glEnableVertexAttribArray(ATTRIBUTE_TEXCOORD);
        
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    }
    
    glBindRenderbuffer(GL_RENDERBUFFER, renderbuffer_);
    [_context presentRenderbuffer:GL_RENDERBUFFER];
}
@end