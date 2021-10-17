//
//  Shader.fsh
//  GLCamera
//
//  Created by Grant Davis on 7/26/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

// to draw a quad texture.
varying highp vec2 textureCoordinate;

uniform sampler2D videoFrame;

void main()
{
    gl_FragColor = texture2D(videoFrame, textureCoordinate);
}

// OLD
//varying lowp vec4 colorVarying;
//
//void main()
//{
//    gl_FragColor = colorVarying;
//}
