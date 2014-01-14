//
//  Shader.vsh
//  test
//
//  Created by ramemiso on 2013/09/23.
//  Copyright (c) 2013年 ramemiso. All rights reserved.
//

#version 300 es

#define ATTRIB_POSITION 0
#define ATTRIB_NORMAL 1

layout (location = ATTRIB_POSITION) in vec4 vertexPosition;
layout (location = ATTRIB_NORMAL) in vec3 vertexNormal;

out mediump vec3 normal;

layout (std140) uniform CommonMatrix
{
	mat4 projectionMatrix;
	mat4 viewMatrix;
};

uniform mat4 modelMatrix;
uniform mat3 normalMatrix;

void main()
{
	normal = normalMatrix * vertexNormal;
	
	mat4 modelViewProjectionMatrix = projectionMatrix * viewMatrix * modelMatrix;
    gl_Position = modelViewProjectionMatrix * vertexPosition;
}
