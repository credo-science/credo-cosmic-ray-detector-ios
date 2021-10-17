//
//  pixelMathImplementation.c
//  NaturalActivity
//
//  Created by Tom Andersen on 2018-04-01.
//
// NOTE - this is included as both a metal file AND a c file.

float heatMapInitial(float total)
{
    return total;
}

float heatMapUpdate(float total, float heat)
{
    const float kHeatMapMemory = 0.03; // total up about the last  hundred frames to get running average noise
    const float kOneMinusHeatMap = 1.0 - kHeatMapMemory; // total up about the last  hundred frames to get running average noise
    return (kHeatMapMemory*total + kOneMinusHeatMap*heat);
}

float pixelScore(float total, float heat)
{
    float diff = total - heat;
    return (total > 4 && diff > 4*heat) ? diff*diff : 0.0f;
}


