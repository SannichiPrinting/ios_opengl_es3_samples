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
	POT,
	PLATE,
	POT_AABB,
	
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

static float plate_verteces[] =
{
	-0.15f, -0.1f, 0.0f,
	 0.15f, -0.1f, 0.0f,
	-0.15f,  0.2f, 0.0f,
	 0.15f,  0.2f, 0.0f,
};

static float plate_normals[] =
{
	-0.1f, -0.1f, 1.0f,
	0.1f, -0.1f, 1.0f,
	-0.1f, 0.1f, 1.0f,
	0.1f, 0.1f, 1.0f,
};

static short plate_indeces[] =
{
	0, 1, 2, 3,
};

static short aabb_indeces[] =
{
	0, 1, 3, 2, 7, 6, 4, 5,
	-1,
	3, 7, 0, 4, 1, 5, 2, 6,
};

@interface RMViewController () {
    GLuint _program;
    
    float _rotation;
	
	DrawObject _drawObjects[DRAW_OBJECT::COUNT];
	GLuint _query;
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
	
	// ポットのAABB作成
	GLKVector3 minPos = {FLT_MAX, FLT_MAX, FLT_MAX};
	GLKVector3 maxPos = {-FLT_MAX, -FLT_MAX, -FLT_MAX};
	for (uint32_t i = 0; i < sizeof(teapot_vertices) / sizeof(teapot_vertices[0]); i += 3)
	{
		minPos.x = std::min(minPos.x, teapot_vertices[i]);
		minPos.y = std::min(minPos.y, teapot_vertices[i + 1]);
		minPos.z = std::min(minPos.z, teapot_vertices[i + 2]);
		
		maxPos.x = std::max(maxPos.x, teapot_vertices[i]);
		maxPos.y = std::max(maxPos.y, teapot_vertices[i + 1]);
		maxPos.z = std::max(maxPos.z, teapot_vertices[i + 2]);
	}
	
	float aabb_verteces[] =
	{
		minPos.x, minPos.y, minPos.z,
		maxPos.x, minPos.y, minPos.z,
		maxPos.x, minPos.y, maxPos.z,
		minPos.x, minPos.y, maxPos.z,
		
		minPos.x, maxPos.y, minPos.z,
		maxPos.x, maxPos.y, minPos.z,
		maxPos.x, maxPos.y, maxPos.z,
		minPos.x, maxPos.y, maxPos.z,
	};
	
	
	float* dataBufferListPosition[] =
	{
		teapot_vertices,
		plate_verteces,
		aabb_verteces,
	};
	uint32_t dataSizeListPosition[] =
	{
		sizeof(teapot_vertices),
		sizeof(plate_verteces),
		sizeof(aabb_verteces),
	};
	float* dataBufferListNormal[] =
	{
		teapot_normals,
		plate_normals,
		aabb_verteces,
	};
	uint32_t dataSizeListNormal[] =
	{
		sizeof(teapot_normals),
		sizeof(plate_normals),
		sizeof(aabb_verteces),
	};
	short* dataBufferListIndex[] =
	{
		teapot_indices,
		plate_indeces,
		aabb_indeces,
	};
	uint32_t dataSizeListIndex[] =
	{
		sizeof(teapot_indices),
		sizeof(plate_indeces),
		sizeof(aabb_indeces),
	};
	
	for (uint32_t i = 0; i < DRAW_OBJECT::COUNT; ++i)
	{
		auto& obj = _drawObjects[i];
		
		glGenVertexArrays(1, &obj.vao);
		glBindVertexArray(obj.vao);
		
		glGenBuffers(1, &obj.vbo_position);
		glBindBuffer(GL_ARRAY_BUFFER, obj.vbo_position);
		glBufferData(GL_ARRAY_BUFFER, dataSizeListPosition[i], dataBufferListPosition[i], GL_STATIC_DRAW);
		
		glEnableVertexAttribArray(ATTRIB_POSITION);
		glVertexAttribPointer(ATTRIB_POSITION, 3, GL_FLOAT, GL_FALSE, 12, BUFFER_OFFSET(0));

		glGenBuffers(1, &obj.vbo_normal);
		glBindBuffer(GL_ARRAY_BUFFER, obj.vbo_normal);
		glBufferData(GL_ARRAY_BUFFER, dataSizeListNormal[i], dataBufferListNormal[i], GL_STATIC_DRAW);

		glEnableVertexAttribArray(ATTRIB_NORMAL);
		glVertexAttribPointer(ATTRIB_NORMAL, 3, GL_FLOAT, GL_FALSE, 12, BUFFER_OFFSET(0));
		
		glGenBuffers(1, &obj.ibo);
		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, obj.ibo);
		
		glBufferData(GL_ELEMENT_ARRAY_BUFFER, dataSizeListIndex[i], dataBufferListIndex[i], GL_STATIC_DRAW);
		glBindVertexArray(0);
	}
	
	// クエリオブジェクト作成
	glGenQueries(1, &_query);
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
	
	glDeleteQueries(1, &_query);
	
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
    
	GLKMatrix4 modelMatrix = GLKMatrix4MakeTranslation(0.0f, 0.0f, -0.3f);
	modelMatrix = GLKMatrix4Rotate(modelMatrix, _rotation, 0.0f, 1.0f, 0.0f);
	GLKMatrix4 modelViewMatrix = GLKMatrix4Multiply(viewMatrix, modelMatrix);
	
    _drawObjects[DRAW_OBJECT::POT].normalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelViewMatrix), NULL);
    _drawObjects[DRAW_OBJECT::POT].modelViewProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);

	modelMatrix = GLKMatrix4MakeRotation(sinf(_rotation) * 1.5f, 0.0f, 1.0f, 0.0f);
	modelViewMatrix = GLKMatrix4Multiply(viewMatrix, modelMatrix);
	
    _drawObjects[DRAW_OBJECT::PLATE].normalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelViewMatrix), NULL);
    _drawObjects[DRAW_OBJECT::PLATE].modelViewProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
    
    _rotation += self.timeSinceLastUpdate * 1.0f;
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
	uint32_t indexCountList[] =
	{
		sizeof(teapot_indices) / sizeof(teapot_indices[0]),
		sizeof(plate_indeces) / sizeof(plate_indeces[0]),
		sizeof(aabb_indeces) / sizeof(aabb_indeces[0]),
	};

	// 深度値だけを描画
	glColorMask(GL_FALSE, GL_FALSE, GL_FALSE, GL_FALSE);
    glClear(GL_DEPTH_BUFFER_BIT);

	glUseProgram(_program);
 
	// 板の描画
    glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, _drawObjects[DRAW_OBJECT::PLATE].modelViewProjectionMatrix.m);
    glUniformMatrix3fv(uniforms[UNIFORM_NORMAL_MATRIX], 1, 0, _drawObjects[DRAW_OBJECT::PLATE].normalMatrix.m);
	
	glBindVertexArray(_drawObjects[DRAW_OBJECT::PLATE].vao);
	glDrawElements(GL_TRIANGLE_STRIP, indexCountList[DRAW_OBJECT::PLATE], GL_UNSIGNED_SHORT, NULL);

	// ポットのAABB描画
    glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, _drawObjects[DRAW_OBJECT::POT].modelViewProjectionMatrix.m);
    glUniformMatrix3fv(uniforms[UNIFORM_NORMAL_MATRIX], 1, 0, _drawObjects[DRAW_OBJECT::POT].normalMatrix.m);
	
	glBindVertexArray(_drawObjects[DRAW_OBJECT::POT_AABB].vao);
	glBeginQuery(GL_ANY_SAMPLES_PASSED, _query);
	glDrawElements(GL_TRIANGLE_STRIP, indexCountList[DRAW_OBJECT::POT_AABB], GL_UNSIGNED_SHORT, NULL);
	glEndQuery(GL_ANY_SAMPLES_PASSED);
	
	// クエリの結果を取得
	GLuint queryResult;
	glGetQueryObjectuiv(_query, GL_QUERY_RESULT, &queryResult);
	
	// ここから通常の描画
	glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);
    glClearColor(0.65f, 0.65f, 0.65f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

	// 板の描画
	glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, _drawObjects[DRAW_OBJECT::PLATE].modelViewProjectionMatrix.m);
	glUniformMatrix3fv(uniforms[UNIFORM_NORMAL_MATRIX], 1, 0, _drawObjects[DRAW_OBJECT::PLATE].normalMatrix.m);
	
	// ポットが描画できるかどうかで色を変える
	if (queryResult != GL_FALSE)
	{
		glUniform4f(uniforms[UNIFORM_COLOR], 1.0f, 0.4f, 0.4f, 1.0f);
	}
	else
	{
		glUniform4f(uniforms[UNIFORM_COLOR], 0.4f, 1.0f, 0.4f, 1.0f);
	}
	glBindVertexArray(_drawObjects[DRAW_OBJECT::PLATE].vao);
	glDrawElements(GL_TRIANGLE_STRIP, indexCountList[DRAW_OBJECT::PLATE], GL_UNSIGNED_SHORT, NULL);
	
	// ポットの描画
	if (queryResult != GL_FALSE)
	{
		glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, _drawObjects[DRAW_OBJECT::POT].modelViewProjectionMatrix.m);
		glUniformMatrix3fv(uniforms[UNIFORM_NORMAL_MATRIX], 1, 0, _drawObjects[DRAW_OBJECT::POT].normalMatrix.m);
		glUniform4f(uniforms[UNIFORM_COLOR], 0.4f, 0.4f, 1.0f, 1.0f);
		
		glBindVertexArray(_drawObjects[DRAW_OBJECT::POT].vao);
		glDrawElements(GL_TRIANGLE_STRIP, indexCountList[DRAW_OBJECT::POT], GL_UNSIGNED_SHORT, NULL);
	}

#if 0
	glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, _drawObjects[DRAW_OBJECT::POT].modelViewProjectionMatrix.m);
	glUniformMatrix3fv(uniforms[UNIFORM_NORMAL_MATRIX], 1, 0, _drawObjects[DRAW_OBJECT::POT].normalMatrix.m);
	glUniform4f(uniforms[UNIFORM_COLOR], 0.4f, 0.4f, 0.4f, 1.0f);
	
	glBindVertexArray(_drawObjects[DRAW_OBJECT::POT_AABB].vao);
	glDrawElements(GL_TRIANGLE_STRIP, indexCountList[DRAW_OBJECT::POT_AABB], GL_UNSIGNED_SHORT, NULL);
#endif
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
