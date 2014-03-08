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

#include <algorithm>

#include "teapot.h"

#define BUFFER_OFFSET(i) ((char *)NULL + (i))

// Uniform index.
enum
{
    UNIFORM_MODELVIEWPROJECTION_MATRIX,
    UNIFORM_NORMAL_MATRIX,
	UNIFORM_COLOR,
    NUM_UNIFORMS
};
GLint uniforms[NUM_UNIFORMS];


enum
{
	ATTRIB_POSITION,
	ATTRIB_NORMAL,
};

enum DRAW_OBJECT
{
	BOX0,
	BOX1,
	
	COUNT
};

struct DrawObject
{
    GLKMatrix4 modelViewProjectionMatrix;
    GLKMatrix3 normalMatrix;
	
    GLuint vao;
	
    GLuint vbo_position;
    GLuint vbo_normal;
    GLuint ibo;
};

static float box_verteces[] =
{
	-2.0f, -1.0f, -1.0f,
	2.0f, -1.0f, -1.0f,
	2.0f, -1.0f, 1.0f,
	-2.0f, -1.0f, 1.0f,
	
	-2.0f, 1.0f, -1.0f,
	2.0f, 1.0f, -1.0f,
	2.0f, 1.0f, 1.0f,
	-2.0f, 1.0f, 1.0f,
};

static short box_indeces[] =
{
	0, 1, 3, 2, 7, 6, 4, 5,
	-1,
	3, 7, 0, 4, 1, 5, 2, 6,
};

@interface RMViewController () {
    GLuint _program;
    
    float _rotation;
	
	DrawObject _drawObjects[DRAW_OBJECT::COUNT];
	GLuint _queryList[2];
}
@property (strong, nonatomic) EAGLContext *context;

- (void)setupGL;
- (void)tearDownGL;

- (BOOL)loadShaders;
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
    
    [self loadShaders];
    
    glEnable(GL_DEPTH_TEST);
	
	glEnable(GL_PRIMITIVE_RESTART_FIXED_INDEX);
	
	for (uint32_t i = 0; i < DRAW_OBJECT::COUNT; ++i)
	{
		auto& obj = _drawObjects[i];
		
		glGenVertexArrays(1, &obj.vao);
		glBindVertexArray(obj.vao);
		
		glGenBuffers(1, &obj.vbo_position);
		glBindBuffer(GL_ARRAY_BUFFER, obj.vbo_position);
		glBufferData(GL_ARRAY_BUFFER, sizeof(box_verteces), box_verteces, GL_STATIC_DRAW);
		
		glEnableVertexAttribArray(ATTRIB_POSITION);
		glVertexAttribPointer(ATTRIB_POSITION, 3, GL_FLOAT, GL_FALSE, 12, BUFFER_OFFSET(0));

		glGenBuffers(1, &obj.vbo_normal);
		glBindBuffer(GL_ARRAY_BUFFER, obj.vbo_normal);
		glBufferData(GL_ARRAY_BUFFER, sizeof(box_verteces), box_verteces, GL_STATIC_DRAW);

		glEnableVertexAttribArray(ATTRIB_NORMAL);
		glVertexAttribPointer(ATTRIB_NORMAL, 3, GL_FLOAT, GL_FALSE, 12, BUFFER_OFFSET(0));
		
		glGenBuffers(1, &obj.ibo);
		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, obj.ibo);
		
		glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(box_indeces), box_indeces, GL_STATIC_DRAW);
		glBindVertexArray(0);
	}
	
	// クエリオブジェクト作成
	glGenQueries(2, _queryList);
}

- (void)tearDownGL
{
    [EAGLContext setCurrentContext:self.context];
    
	for (auto& obj : _drawObjects)
	{
		glDeleteBuffers(1, &obj.ibo);
		glDeleteBuffers(1, &obj.vbo_normal);
		glDeleteBuffers(1, &obj.vbo_position);
		glDeleteVertexArrays(1, &obj.vao);
    }
	
	glDeleteQueries(2, _queryList);
	
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
	
	GLKMatrix4 viewMatrix = GLKMatrix4MakeLookAt(0.0f, 0.2f, 10.5f, 0.0f, 0.05f, 0.0f, 0.0f, 1.0f, 0.0f);
    
	GLKMatrix4 modelMatrix = GLKMatrix4MakeTranslation(-1.6f, 0.5f, 0.0f);
	modelMatrix = GLKMatrix4Rotate(modelMatrix, _rotation, 1.0f, 1.0f, 0.0f);
	GLKMatrix4 modelViewMatrix = GLKMatrix4Multiply(viewMatrix, modelMatrix);
	
    _drawObjects[DRAW_OBJECT::BOX0].normalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelViewMatrix), NULL);
    _drawObjects[DRAW_OBJECT::BOX0].modelViewProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);

	modelMatrix = GLKMatrix4MakeTranslation(1.6f, -0.5f, 0.0f);
	modelMatrix = GLKMatrix4Rotate(modelMatrix, _rotation, 0.0f, 1.0f, 1.0f);
	modelViewMatrix = GLKMatrix4Multiply(viewMatrix, modelMatrix);
	
    _drawObjects[DRAW_OBJECT::BOX1].normalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelViewMatrix), NULL);
    _drawObjects[DRAW_OBJECT::BOX1].modelViewProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
    
    _rotation += self.timeSinceLastUpdate * 1.0f;
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
	// オブジェクトの描画
	auto renderObject = [](DrawObject& obj, GLKVector4 color)
	{
		uint32_t box_index_count = sizeof(box_indeces) / sizeof(box_indeces[0]);
		
		glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, obj.modelViewProjectionMatrix.m);
		glUniformMatrix3fv(uniforms[UNIFORM_NORMAL_MATRIX], 1, 0, obj.normalMatrix.m);
		
		glUniform4fv(uniforms[UNIFORM_COLOR], 1, color.v);
		
		glBindVertexArray(obj.vao);
		glDrawElements(GL_TRIANGLE_STRIP, box_index_count, GL_UNSIGNED_SHORT, NULL);
	};
	
	glUseProgram(_program);
	
	bool isHit = false;
	
	// 深度値だけを描画
	glColorMask(GL_FALSE, GL_FALSE, GL_FALSE, GL_FALSE);
	glClear(GL_DEPTH_BUFFER_BIT);

	auto colorDummy = GLKVector4Make(0.0f, 0.0f, 0.0f, 0.0f);
	
	// Box0の表ポリゴンよりBox1の裏ポリゴンの方が前面にあるか？
	glDepthFunc(GL_ALWAYS);
	glDepthMask(GL_TRUE);
	glCullFace(GL_BACK);
	renderObject(_drawObjects[DRAW_OBJECT::BOX0], colorDummy);

	glDepthFunc(GL_GREATER);
	glDepthMask(GL_FALSE);
	glCullFace(GL_FRONT);

	glBeginQuery(GL_ANY_SAMPLES_PASSED_CONSERVATIVE, _queryList[0]);
	renderObject(_drawObjects[DRAW_OBJECT::BOX1], colorDummy);
	glEndQuery(GL_ANY_SAMPLES_PASSED_CONSERVATIVE);
	
	// Box1の表ポリゴンよりBox1の裏ポリゴンの方が前面にあるか？
	glDepthFunc(GL_ALWAYS);
	glDepthMask(GL_TRUE);
	glCullFace(GL_BACK);
	renderObject(_drawObjects[DRAW_OBJECT::BOX1], colorDummy);
		
	glDepthFunc(GL_GREATER);
	glDepthMask(GL_FALSE);
	glCullFace(GL_FRONT);
	
	glBeginQuery(GL_ANY_SAMPLES_PASSED_CONSERVATIVE, _queryList[1]);
	renderObject(_drawObjects[DRAW_OBJECT::BOX0], colorDummy);
	glEndQuery(GL_ANY_SAMPLES_PASSED_CONSERVATIVE);

	// 両方を満たしていた場合は衝突している
	GLuint queryResults[2];
	glGetQueryObjectuiv(_queryList[0], GL_QUERY_RESULT, &queryResults[0]);
	glGetQueryObjectuiv(_queryList[1], GL_QUERY_RESULT, &queryResults[1]);

	isHit = (queryResults[0] && queryResults[1]);
	
	// ここから通常の描画
	glEnable(GL_DEPTH_TEST);
	glDepthFunc(GL_LESS);
	glDepthMask(GL_TRUE);
	glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);
	glClearColor(0.65f, 0.65f, 0.65f, 1.0f);
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
	
	for (auto& obj : _drawObjects)
	{
		auto color = (isHit)
			? GLKVector4Make(1.0f, 0.4f, 0.4f, 1.0f)
			: GLKVector4Make(0.4f, 1.0f, 0.4f, 1.0f);

		renderObject(obj, color);
	}
}

#pragma mark -  OpenGL ES 2 shader compilation

- (BOOL)loadShaders
{
    GLuint vertShader, fragShader;
    NSString *vertShaderPathname, *fragShaderPathname;
    
    // Create shader program.
    _program = glCreateProgram();
    
    // Create and compile vertex shader.
    vertShaderPathname = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"vsh"];
    if (![self compileShader:&vertShader type:GL_VERTEX_SHADER file:vertShaderPathname]) {
        NSLog(@"Failed to compile vertex shader");
        return NO;
    }
    
    // Create and compile fragment shader.
    fragShaderPathname = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"fsh"];
    if (![self compileShader:&fragShader type:GL_FRAGMENT_SHADER file:fragShaderPathname]) {
        NSLog(@"Failed to compile fragment shader");
        return NO;
    }
    
    // Attach vertex shader to program.
    glAttachShader(_program, vertShader);
    
    // Attach fragment shader to program.
    glAttachShader(_program, fragShader);
	   
    // Link program.
    if (![self linkProgram:_program]) {
        NSLog(@"Failed to link program: %d", _program);
        
        if (vertShader) {
            glDeleteShader(vertShader);
            vertShader = 0;
        }
        if (fragShader) {
            glDeleteShader(fragShader);
            fragShader = 0;
        }
        if (_program) {
            glDeleteProgram(_program);
            _program = 0;
        }
        
        return NO;
    }
    
    // Get uniform locations.
    uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX] = glGetUniformLocation(_program, "modelViewProjectionMatrix");
    uniforms[UNIFORM_NORMAL_MATRIX] = glGetUniformLocation(_program, "normalMatrix");
	uniforms[UNIFORM_COLOR] = glGetUniformLocation(_program, "color");
    
    // Release vertex and fragment shaders.
    if (vertShader) {
        glDetachShader(_program, vertShader);
        glDeleteShader(vertShader);
    }
    if (fragShader) {
        glDetachShader(_program, fragShader);
        glDeleteShader(fragShader);
    }
    
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
