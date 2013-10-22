//
//  Shader.fsh
//  test
//
//  Created by ramemiso on 2013/09/23.
//  Copyright (c) 2013年 ramemiso. All rights reserved.
//

#version 300 es

in mediump vec2 texcoord;

out mediump vec4 fragColor;

uniform mediump sampler2D hdrTexture;

void main()
{
	fragColor = texture(hdrTexture, texcoord);
	fragColor.rgb -= 0.25;
	
	if (any(lessThan(fragColor.rgb, vec3(0.0, 0.0, 0.0))))
	{
		fragColor = vec4(0.0, 0.0, 0.0, 0.0);
	}
}
