

#import "ES1Renderer.h"

@implementation ES1Renderer

// Create an OpenGL ES 1.1 context
- (id)init {
	return [self initWithDepth:false andAA:false  andFSAASamples:0 andRetina:false];
}

- (id)initWithDepth:(bool)depth andAA:(bool)fsaa andFSAASamples:(int)samples andRetina:(bool)retina {

    if((self = [super init])) {
		
		depthEnabled = depth;
		fsaaEnabled = fsaa;
		fsaaSamples = samples;
		retinaEnabled = retina;
        bResize = false;
				
        context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1];
		NSLog(@"Creating OpenGL ES1 Renderer");
        
        if(!context || ![EAGLContext setCurrentContext:context]) {
			NSLog(@"OpenGL ES1 failed");
            [self release];
            return nil;
        }
        
        const GLubyte * extensions = glGetString(GL_EXTENSIONS);
        if(extensions != NULL && fsaaEnabled) {
            if(strstr((const char*)extensions, "GL_APPLE_framebuffer_multisample")) {
                fsaaEnabled = true;
            } else {
                fsaaEnabled = false;
            }
        } else {
            fsaaEnabled = false;
        }
	}

    return self;
}

-(EAGLContext*) context {
	return context;
}

- (void)startRender {
    [EAGLContext setCurrentContext:context];
}

- (void)finishRender {
	
	if(fsaaEnabled) {
		if(depthEnabled) {
			GLenum attachments[] = {GL_COLOR_ATTACHMENT0_OES, GL_DEPTH_ATTACHMENT_OES};
			glDiscardFramebufferEXT(GL_READ_FRAMEBUFFER_APPLE, 2, attachments);
		} else {
			GLenum attachments[] = {GL_COLOR_ATTACHMENT0_OES};
			glDiscardFramebufferEXT(GL_READ_FRAMEBUFFER_APPLE, 1, attachments);
		}
        
		glBindFramebufferOES(GL_READ_FRAMEBUFFER_APPLE, fsaaFrameBuffer);
		glBindFramebufferOES(GL_DRAW_FRAMEBUFFER_APPLE, defaultFramebuffer);
		glResolveMultisampleFramebufferAPPLE();
	}
	
    glBindRenderbufferOES(GL_RENDERBUFFER_OES, colorRenderbuffer);
    if(bResize) {
        /**
         *  when resizing glView there is a visual glitch
         *  which shows the screen distorted for a split second.
         *  the below fixes it.
         */
        glClear(GL_COLOR_BUFFER_BIT);
        bResize = false;
    }
    [context presentRenderbuffer:GL_RENDERBUFFER_OES];
	
	if(fsaaEnabled) {
		glBindFramebufferOES(GL_FRAMEBUFFER_OES, fsaaFrameBuffer);
    }
}

- (BOOL)resizeFromLayer:(CAEAGLLayer *)layer
{
	
    //[self destroyFramebuffer];
	BOOL bOk = NO;
	if(defaultFramebuffer == 0)
	{
		bOk = [self createFramebuffer:layer];
		bResize = true;
		
	}
	return bOk;
}
- (int)getFrameBufferID
{
	return (int)defaultFramebuffer;
}

- (BOOL)createFramebuffer:(CAEAGLLayer *)layer {
	if(defaultFramebuffer != 0)
	{
		return YES;

	}else
	{
		NSLog(@"dfasdfa");
	}
	if(!context)
	{
		return NO;

	}
	glGenFramebuffersOES(1, &defaultFramebuffer);
	glGenRenderbuffersOES(1, &colorRenderbuffer);
	
	glBindFramebufferOES(GL_FRAMEBUFFER_OES, defaultFramebuffer);
	glBindRenderbufferOES(GL_RENDERBUFFER_OES, colorRenderbuffer);
    
    [context renderbufferStorage:GL_RENDERBUFFER_OES fromDrawable:layer];
	glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_RENDERBUFFER_OES, colorRenderbuffer);
    
    if(fsaaEnabled) {
        glGenFramebuffersOES(1, &fsaaFrameBuffer);
        glGenRenderbuffersOES(1, &fsaaColorRenderBuffer);
    }
	
	
	glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_WIDTH_OES, &backingWidth);
	glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_HEIGHT_OES, &backingHeight);
	
	NSLog(@"backingWidth %d, backingHeight %d", backingWidth, backingHeight);
	if(backingWidth == 0)
	{
		return NO;
	}
	GLenum err = glGetError();
	if (err != GL_NO_ERROR)
	{
		NSLog(@"Error. glError: 0x%04X", err);

	}
	if(fsaaEnabled) {
		glBindFramebufferOES(GL_FRAMEBUFFER_OES, fsaaFrameBuffer);
		glBindRenderbufferOES(GL_RENDERBUFFER_OES, fsaaColorRenderBuffer);
		glRenderbufferStorageMultisampleAPPLE(GL_RENDERBUFFER_OES, fsaaSamples, GL_RGB5_A1_OES, backingWidth, backingHeight);
		glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_RENDERBUFFER_OES, fsaaColorRenderBuffer);
	}
	
	if(depthEnabled) {
		if(!depthRenderbuffer) {
			glGenRenderbuffersOES(1, &depthRenderbuffer);
        }
		
		glBindRenderbufferOES(GL_RENDERBUFFER_OES, depthRenderbuffer);
		
		if(fsaaEnabled) {
			glRenderbufferStorageMultisampleAPPLE(GL_RENDERBUFFER_OES, fsaaSamples, GL_DEPTH_COMPONENT16_OES, backingWidth, backingHeight);
			glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_DEPTH_ATTACHMENT_OES, GL_RENDERBUFFER_OES, depthRenderbuffer);
		} else {
			glRenderbufferStorageOES(GL_RENDERBUFFER_OES, GL_DEPTH_COMPONENT16_OES, backingWidth, backingHeight); // GL DEPTH COMPONENT ON THIS LINE ISNT CORRECT POTENTIALLY
			glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_DEPTH_ATTACHMENT_OES, GL_RENDERBUFFER_OES, depthRenderbuffer);
		}
	}
	
	GLenum result = glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES);
	err = glGetError();
	if (err != GL_NO_ERROR)
	{
		NSLog(@"Error. glError: 0x%04X", err);
		
	}
	if(result != GL_FRAMEBUFFER_COMPLETE_OES) {
		NSLog(@"failed to make complete framebuffer object %x", result);
		return NO;
	}
	
	return YES;
}


- (void)destroyFramebuffer {
    if(defaultFramebuffer) {
        glDeleteFramebuffersOES(1, &defaultFramebuffer);
        defaultFramebuffer = 0;
    }
    
    if(colorRenderbuffer) {
        glDeleteRenderbuffersOES(1, &colorRenderbuffer);
        colorRenderbuffer = 0;
    }
    
	if(depthRenderbuffer) {
		glDeleteRenderbuffersOES(1, &depthRenderbuffer);
		depthRenderbuffer = 0;
	}
	
	if(fsaaFrameBuffer) {
		glDeleteRenderbuffersOES(1, &fsaaFrameBuffer);
		fsaaFrameBuffer = 0;
	}
	
	if(fsaaColorRenderBuffer) {
		glDeleteRenderbuffersOES(1, &fsaaColorRenderBuffer);
		fsaaColorRenderBuffer = 0;
	}
}

- (void)dealloc {
    [self destroyFramebuffer];
	
    // Tear down context
    if([EAGLContext currentContext] == context) {
        [EAGLContext setCurrentContext:nil];
    }

    [context release];
    context = nil;

    [super dealloc];
}

- (NSInteger)getWidth {
    return backingWidth;
} 

- (NSInteger)getHeight {
    return backingHeight;
}

@end
