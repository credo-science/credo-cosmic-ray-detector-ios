//
//  Shader.vsh
//  GLCamera
//
//  Created by Grant Davis on 7/26/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

// quad draw texture

attribute vec4 position;
attribute vec4 inputTextureCoordinate;

varying vec2 textureCoordinate;

void main()
{
    gl_Position = position;
    textureCoordinate = inputTextureCoordinate.xy;
}

//attribute vec4 position;
//attribute vec4 color;
//
//varying vec4 colorVarying;
//
//uniform float translate;
//
//void main()
//{
//    gl_Position = position;
//    gl_Position.y += sin(translate) / 2.0;
//
//    colorVarying = color;
//}
