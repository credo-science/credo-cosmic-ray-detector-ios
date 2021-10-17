//
//  pixelMath.h
//  Cosmic Ray
//
//  Created by Tom Andersen on 2018-04-01.
//

#ifndef pixelMath_h
#define pixelMath_h

#include <stdint.h>

float heatMapInitial(float total);
float heatMapUpdate(float total, float heat);
float pixelScore(float total, float heat);

#endif /* pixelMath_h */
