//
//  BufferProcessor.m
//  Detection
//
//  Created by Brandon Plaster on 3/18/15.
//  Copyright (c) 2015 BrandonPlaster. All rights reserved.
//

#import "BufferProcessor.h"

@implementation BufferProcessor

// Hough Circle Detector
// Notes:   Assumes you've already allocated memory for destination
//          Assumes the source is edges
+ (int) detectCircles: (vImage_Buffer *)source withRadius:(int)radius useGradient:(BOOL) useGradient outputHough:(vImage_Buffer *)hough{
    
    // TODO: What is the number of points based on?
    int votingThreshold = 50; //MAX(30, radius);
    unsigned char * srcAddress = source->data;
    
    // Hough space is image size + extended by radius in every direction
//    size_t tmpRowBytes = 2*radius+source->rowBytes;
//    size_t tmpHeight = 2*radius+source->height;
    unsigned char *houghAddress = hough->data;
//    vImage_Buffer tmp = {tmpAddress, tmpHeight, 2*radius + source->width, tmpRowBytes};
    
    // Iterate over image space
    unsigned long pixel = 0;
    for (int row = 2; row < source->height - 2; row++) {
        for (int column = 2; column < source->width - 2; column++) {
            pixel = row*source->rowBytes + column;
            if (srcAddress[pixel]) {
                int x0 = column + radius;
                int y0 = row + radius;
                // Draw circle in Hough space
                [self voteCircleAtX:x0 Y:y0 Radius:radius buffer:hough votes:1];
            }
        }
    }
    
    // Iterate over Hough space
    int count = 0;
    for (int row = radius; row < hough->height - radius; row++) {
        for (int column = radius; column < hough->width - radius; column++) {
            pixel = row*hough->rowBytes + column;
            if (houghAddress[pixel] > votingThreshold) {
                int x0 = column - radius;
                int y0 = row - radius;
                // TODO: make so doesn't only find circles contained within borders
                if (x0 > radius && x0 < source->width - radius && y0 > radius && y0 < source->height - radius) {
                    [self voteCircleAtX:x0 Y:y0 Radius:radius buffer:source votes:255];
                    count++;
                }
            }
        }
    }
    
//    free(tmpAddress);

    
    return count;
}

// From http://rosettacode.org/wiki/Bitmap/Midpoint_circle_algorithm
// Assumes buffer is padded to fit full circles
+ (void) voteCircleAtX:(int)x0 Y:(int)y0 Radius:(int)radius buffer:(vImage_Buffer *)buffer votes:(int) value {
    int f = 1 - radius;
    int ddF_x = 0;
    int ddF_y = -2 * radius;
    int x = 0;
    int y = radius;
    unsigned char * data = buffer->data;
    
    data[x0 + (y0 + radius)*buffer->rowBytes] += value;
    data[x0 + (y0 - radius)*buffer->rowBytes] += value;
    data[(x0 + radius) + y0*buffer->rowBytes] += value;
    data[(x0 - radius) + y0*buffer->rowBytes] += value;
    
    while(x < y)
    {
        if(f >= 0)
        {
            y--;
            ddF_y += 2;
            f += ddF_y;
        }
        x++;
        ddF_x += 2;
        f += ddF_x + 1;
        
        data[(x0 + x) + (y0 + y)*buffer->rowBytes] += value;
        data[(x0 - x) + (y0 + y)*buffer->rowBytes] += value;
        data[(x0 + x) + (y0 - y)*buffer->rowBytes] += value;
        data[(x0 - x) + (y0 - y)*buffer->rowBytes] += value;
        data[(x0 + y) + (y0 + x)*buffer->rowBytes] += value;
        data[(x0 - y) + (y0 + x)*buffer->rowBytes] += value;
        data[(x0 + y) + (y0 - x)*buffer->rowBytes] += value;
        data[(x0 - y) + (y0 - x)*buffer->rowBytes] += value;
    }
}


// Canny edge detector
// Notes:   Assumes you've already allocated memory for destination
//          Assumes 1 byte per pixel
+ (void) cannyDetector: (vImage_Buffer *)source toDestination: (vImage_Buffer *)destination withMinVal:(int)minVal andMaxVal:(int)maxVal {
    
    unsigned char *destAddress = (unsigned char *)destination->data;
    size_t arraySize = source->rowBytes*source->height;
    
    // Gaussian
    const int16_t gaussKernel[25] = {2,4,5,4,2,4,9,12,9,4,5,12,15,12,5,4,9,12,9,4,2,4,5,4,2};
    vImageConvolve_Planar8(source, destination, NULL, 0, 0, gaussKernel, 5, 5, 159, 0, kvImageEdgeExtend);
    
    // Partial derivative arrays
    signed char *gxAddress = malloc(arraySize);
    signed char *gyAddress = malloc(arraySize);
    vImage_Buffer gx = {gxAddress, source->height, source->width, source->rowBytes};
    vImage_Buffer gy = {gyAddress, source->height, source->width, source->rowBytes};
    
    // Sobel
    const int16_t vKernel[9] = {-1, 0, 1, -2, 0, 2, -1, 0, 1};
    const int16_t hKernel[9] = {1, 2, 1, 0, 0, 0, -1, -2, -1};
    vImageConvolve_Planar8(destination, &gx, NULL, 0, 0, hKernel, 3, 3, 1, 0, kvImageEdgeExtend);
    vImageConvolve_Planar8(destination, &gy, NULL, 0, 0, vKernel, 3, 3, 1, 0, kvImageEdgeExtend);
    
    // Direction and Magnitude
    unsigned char *magAddress = malloc(arraySize);
    unsigned char *dirAddress = malloc(arraySize);
    unsigned long pixel = 0;
    for (int row = 0; row < source->height; row++) {
        for (int column = 0; column < source->width; column++) {
            pixel = row*source->rowBytes + column;
            magAddress[pixel] = sqrtf(powf(gxAddress[pixel], 2)+powf(gyAddress[pixel], 2));
            
            // Make sure non-zero denominator
            float angle = 0.;
            if (gxAddress[pixel]) {
                angle = 180 * atanf(gyAddress[pixel]/gxAddress[pixel]) / M_PI;
            } else if (gyAddress[pixel] != 0) {
                angle = 90;
            }
            
            // Discretize values
            int newAngle = 0;
            if (angle >= -22.5 && angle < 22.5) { // [-pi/8,pi/8]
                newAngle = 0;
            } else if (angle >= 22.5 && angle < 67.5) { // [pi/8, 3pi/8]
                newAngle = 45;
            } else if (angle >= -67.5 && angle < -22.5) { // [-3pi/8,-pi/8]
                newAngle = 135;
            } else {
                newAngle = 90;
            }
            dirAddress[pixel] = newAngle;
        }
    }
    
    free(gxAddress);
    free(gyAddress);
    
    // Non-maximal suppression && Double threshold
    // TODO: need to handle border
    int dir = 0, value = 0;
    int strongValue = 255;
    
    for (int row = 1; row < source->height-1; row++) {
        for (int column = 1; column < source->width-1; column++) {
            
            pixel = row*source->rowBytes + column;
            value = magAddress[pixel];
            dir = dirAddress[pixel];
            
            // Check if maximum along gradient
            if (dir == 0) { // [-pi/8,pi/8]
                if (value <= magAddress[(row-1)*source->rowBytes + column] || value <= magAddress[(row+1)*source->rowBytes + column]) {
                    value = 0;
                }
            } else if (dir == 45) { // [pi/8, 3pi/8]
                if (value <= magAddress[(row-1)*source->rowBytes + (column+1)] || value <= magAddress[(row+1)*source->rowBytes + (column-1)]) {
                    value = 0;
                }
            } else if (dir == 135) { // [-3pi/8,-pi/8]
                if (value <= magAddress[(row-1)*source->rowBytes + (column-1)] || value <= magAddress[(row+1)*source->rowBytes + (column+1)]) {
                    value = 0;
                }
            } else {
                if (value <= magAddress[pixel+1] || value <= magAddress[pixel-1]) {
                    value = 0;
                }
            }
            
            // Double Threshold
            if (value > maxVal) {
                value = strongValue;
            } else if (value > minVal && (destAddress[pixel-1] == strongValue || destAddress[(row-1)*source->rowBytes + column] == strongValue
                                          || destAddress[(row-1)*source->rowBytes + (column-1)] == strongValue)) {
                value = strongValue;
            } else {
                value = 0;
            }
            
            destAddress[pixel] = value;
        }
    }

    free(magAddress);
    free(dirAddress);
    
}

@end