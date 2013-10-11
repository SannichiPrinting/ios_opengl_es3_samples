//
//  RMViewController.m
//  test
//
//  Created by ramemiso on 2013/09/23.
//  Copyright (c) 2013年 ramemiso. All rights reserved.
//

#import "RMViewController.h"
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>

#include "teapot.h"

#define BUFFER_OFFSET(i) ((char *)NULL + (i))

//#define GAMMA_CORRECTION_ENABLED
#define GAMMA 2.2f

#ifndef GAMMA_CORRECTION_ENABLED
#define HARDWARE_GAMMA_CORRECTION_ENABLED
#endif

// Uniform index.
enum
{
    UNIFORM_MODELVIEWPROJECTION_MATRIX,
    UNIFORM_NORMAL_MATRIX,
	UNIFORM_GAMMA_CORRECTION_ENABLED,
	UNIFORM_GAMMA,

	UNIFORM_GAMMA_CORRECTION_ENABLED2,
	UNIFORM_GAMMA2,

	NUM_UNIFORMS
};
GLint uniforms[NUM_UNIFORMS];


enum
{
	ATTRIB_POSITION,
	ATTRIB_NORMAL,
	ATTRIB_COLOR,
};


@interface RMViewController () {
    GLuint _program;
    GLuint _program2;
    
    GLKMatrix4 _modelViewProjectionMatrix;
    GLKMatrix3 _normalMatrix;
    float _rotation;
    
    GLuint _vao;
    GLuint _vbo_position;
    GLuint _vbo_normal;
    GLuint _ibo;
	
    GLuint _vao2;
    GLuint _vbo2;
}
@property (strong, nonatomic) EAGLContext *context;

- (void)setupGL;
- (void)tearDownGL;

- (BOOL)loadShaders:(GLuint*)program path:(NSString*)path;
- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file;
- (BOOL)linkProgram:(GLuint)prog;
- (BOOL)validateProgram:(GLuint)prog;
@end

@implementation RMViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];

    if (!self.context) {
        NSLog(@"Failed to create ES context");
    }
    
    GLKView *view = (GLKView *)self.view;
    view.context = self.context;
#ifdef HARDWARE_GAMMA_CORRECTION_ENABLED
	view.drawableColorFormat = GLKViewDrawableColorFormatSRGBA8888;
#endif
    view.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    
    [self setupGL];
}

- (void)dealloc
{    
    [self tearDownGL];
    
    if ([EAGLContext currentContext] == self.context) {
        [EAGLContext setCurrentContext:nil];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];

    if ([self isViewLoaded] && ([[self view] window] == nil)) {
        self.view = nil;
        
        [self tearDownGL];
        
        if ([EAGLContext currentContext] == self.context) {
            [EAGLContext setCurrentContext:nil];
        }
        self.context = nil;
    }

    // Dispose of any resources that can be recreated.
}

- (void)setupGL
{
    [EAGLContext setCurrentContext:self.context];
    
    [self loadShaders:&_program path:@"Shader"];
    [self loadShaders:&_program2 path:@"Shader2"];
	
	uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX] = glGetUniformLocation(_program, "modelViewProjectionMatrix");
    uniforms[UNIFORM_NORMAL_MATRIX] = glGetUniformLocation(_program, "normalMatrix");
    uniforms[UNIFORM_GAMMA_CORRECTION_ENABLED] = glGetUniformLocation(_program, "gammaCorrectionEnabled");
    uniforms[UNIFORM_GAMMA] = glGetUniformLocation(_program, "gamma");

    uniforms[UNIFORM_GAMMA_CORRECTION_ENABLED2] = glGetUniformLocation(_program2, "gammaCorrectionEnabled");
    uniforms[UNIFORM_GAMMA2] = glGetUniformLocation(_program2, "gamma");
    
    glEnable(GL_DEPTH_TEST);
	glEnable(GL_PRIMITIVE_RESTART_FIXED_INDEX);
	
    glGenVertexArrays(1, &_vao);
    glBindVertexArray(_vao);
    
    glGenBuffers(1, &_vbo_position);
    glBindBuffer(GL_ARRAY_BUFFER, _vbo_position);
    glBufferData(GL_ARRAY_BUFFER, sizeof(teapot_vertices), teapot_vertices, GL_STATIC_DRAW);
    
    glEnableVertexAttribArray(ATTRIB_POSITION);
    glVertexAttribPointer(ATTRIB_POSITION, 3, GL_FLOAT, GL_FALSE, 12, BUFFER_OFFSET(0));

	glGenBuffers(1, &_vbo_normal);
    glBindBuffer(GL_ARRAY_BUFFER, _vbo_normal);
    glBufferData(GL_ARRAY_BUFFER, sizeof(teapot_normals), teapot_normals, GL_STATIC_DRAW);

    glEnableVertexAttribArray(ATTRIB_NORMAL);
    glVertexAttribPointer(ATTRIB_NORMAL, 3, GL_FLOAT, GL_FALSE, 12, BUFFER_OFFSET(0));
	
	glGenBuffers(1, &_ibo);
	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _ibo);
	
	glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(teapot_indices), teapot_indices, GL_STATIC_DRAW);
	
    glBindVertexArray(0);
	
	
	static float polyData[] =
	{
		-0.75f, -0.6f, 0.0f,  0.0f, 0.0f, 0.0f,
		-0.75f, -0.3f, 0.0f,  0.0f, 0.0f, 0.0f,
		 0.75f, -0.6f, 0.0f,  1.0f, 1.0f, 1.0f,
		 0.75f, -0.3f, 0.0f,  1.0f, 1.0f, 1.0f,
	};
	
    glGenVertexArrays(1, &_vao2);
    glBindVertexArray(_vao2);
    
    glGenBuffers(1, &_vbo2);
    glBindBuffer(GL_ARRAY_BUFFER, _vbo2);
    glBufferData(GL_ARRAY_BUFFER, sizeof(polyData), polyData, GL_STATIC_DRAW);
    
    glEnableVertexAttribArray(ATTRIB_POSITION);
    glVertexAttribPointer(ATTRIB_POSITION, 3, GL_FLOAT, GL_FALSE, 24, BUFFER_OFFSET(0));
    glEnableVertexAttribArray(ATTRIB_COLOR);
    glVertexAttribPointer(ATTRIB_COLOR, 3, GL_FLOAT, GL_FALSE, 24, BUFFER_OFFSET(12));
	
    glBindVertexArray(0);	
}

- (void)tearDownGL
{
    [EAGLContext setCurrentContext:self.context];
    
	glDeleteBuffers(1, &_ibo);
    glDeleteBuffers(1, &_vbo_normal);
    glDeleteBuffers(1, &_vbo_position);
    glDeleteVertexArrays(1, &_vao);
	
	glDeleteBuffers(1, &_vbo2);
	glDeleteVertexArrays(1, &_vao2);
    
    if (_program) {
        glDeleteProgram(_program);
        _program = 0;
    }
}

#pragma mark - GLKView and GLKViewController delegate methods

- (void)update
{
    float aspect = fabsf(self.view.bounds.size.width / self.view.bounds.size.height);
    GLKMatrix4 projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(65.0f), aspect, 0.1f, 100.0f);
	
	GLKMatrix4 viewMatrix = GLKMatrix4MakeLookAt(0.0f, 0.2f, 0.5f, 0.0f, 0.05f, 0.0f, 0.0f, 1.0f, 0.0f);
    
	GLKMatrix4 modelMatrix = GLKMatrix4MakeRotation(_rotation, 0.0f, 1.0f, 0.0f);
    
	GLKMatrix4 modelViewMatrix = GLKMatrix4Multiply(viewMatrix, modelMatrix);
	
    _normalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelViewMatrix), NULL);
    
    _modelViewProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
    
//    _rotation += self.timeSinceLastUpdate * 1.0f;
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
	float gray = 0.5f;
#ifdef GAMMA_CORRECTION_ENABLED
	gray = powf(gray, 1.0f / GAMMA);
#endif	
    glClearColor(gray, gray, gray, gray);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    glBindVertexArray(_vao);
    glUseProgram(_program);

#ifdef GAMMA_CORRECTION_ENABLED
	GLint gammaCorrectionEnabled = 1;
#else
	GLint gammaCorrectionEnabled = 0;
#endif
	
    glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, _modelViewProjectionMatrix.m);
    glUniformMatrix3fv(uniforms[UNIFORM_NORMAL_MATRIX], 1, 0, _normalMatrix.m);
	glUniform1i(uniforms[UNIFORM_GAMMA_CORRECTION_ENABLED], gammaCorrectionEnabled);
	glUniform1f(uniforms[UNIFORM_GAMMA], GAMMA);
	
	uint32_t indexCount = sizeof(teapot_indices) / sizeof(teapot_indices[0]);
	glDrawElements(GL_TRIANGLE_STRIP, indexCount, GL_UNSIGNED_SHORT, NULL);
	
	
	glBindVertexArray(_vao2);
	glUseProgram(_program2);

	glUniform1i(uniforms[UNIFORM_GAMMA_CORRECTION_ENABLED2], gammaCorrectionEnabled);
	glUniform1f(uniforms[UNIFORM_GAMMA2], GAMMA);

	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}

#pragma mark -  OpenGL ES 2 shader compilation

- (BOOL)loadShaders:(GLuint*)program path:(NSString*)path
{
    GLuint vertShader, fragShader;
    NSString *vertShaderPathname, *fragShaderPathname;
    
    // Create shader program.
    GLuint programTmp = glCreateProgram();
    
    // Create and compile vertex shader.
    vertShaderPathname = [[NSBundle mainBundle] pathForResource:path ofType:@"vsh"];
    if (![self compileShader:&vertShader type:GL_VERTEX_SHADER file:vertShaderPathname]) {
        NSLog(@"Failed to compile vertex shader");
        return NO;
    }
    
    // Create and compile fragment shader.
    fragShaderPathname = [[NSBundle mainBundle] pathForResource:path ofType:@"fsh"];
    if (![self compileShader:&fragShader type:GL_FRAGMENT_SHADER file:fragShaderPathname]) {
        NSLog(@"Failed to compile fragment shader");
        return NO;
    }
    
    // Attach vertex shader to program.
    glAttachShader(programTmp, vertShader);
    
    // Attach fragment shader to program.
    glAttachShader(programTmp, fragShader);
	
    // Link program.
    if (![self linkProgram:programTmp]) {
        NSLog(@"Failed to link program: %d", programTmp);
        
        if (vertShader) {
            glDeleteShader(vertShader);
            vertShader = 0;
        }
        if (fragShader) {
            glDeleteShader(fragShader);
            fragShader = 0;
        }
        if (programTmp) {
            glDeleteProgram(programTmp);
            programTmp = 0;
        }
        
        return NO;
    }
    
    // Release vertex and fragment shaders.
    if (vertShader) {
        glDetachShader(programTmp, vertShader);
        glDeleteShader(vertShader);
    }
    if (fragShader) {
        glDetachShader(programTmp, fragShader);
        glDeleteShader(fragShader);
    }
    
	*program = programTmp;
    return YES;
}

- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file
{
    GLint status;
    const GLchar *source;
    
    source = (GLchar *)[[NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil] UTF8String];
    if (!source) {
        NSLog(@"Failed to load vertex shader");
        return NO;
    }
    
    *shader = glCreateShader(type);
    glShaderSource(*shader, 1, &source, NULL);
    glCompileShader(*shader);
    
#if defined(DEBUG)
    GLint logLength;
    glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetShaderInfoLog(*shader, logLength, &logLength, log);
        NSLog(@"Shader compile log:\n%s", log);
        free(log);
    }
#endif
    
    glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);
    if (status == 0) {
        glDeleteShader(*shader);
        return NO;
    }
    
    return YES;
}

- (BOOL)linkProgram:(GLuint)prog
{
    GLint status;
    glLinkProgram(prog);
    
#if defined(DEBUG)
    GLint logLength;
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program link log:\n%s", log);
        free(log);
    }
#endif
    
    glGetProgramiv(prog, GL_LINK_STATUS, &status);
    if (status == 0) {
        return NO;
    }
    
    return YES;
}

- (BOOL)validateProgram:(GLuint)prog
{
    GLint logLength, status;
    
    glValidateProgram(prog);
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program validate log:\n%s", log);
        free(log);
    }
    
    glGetProgramiv(prog, GL_VALIDATE_STATUS, &status);
    if (status == 0) {
        return NO;
    }
    
    return YES;
}

@end
