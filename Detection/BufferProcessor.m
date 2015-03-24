//
//  BufferProcessor.m
//  Detection
//
//  Created by Brandon Plaster on 3/18/15.
//  Copyright (c) 2015 BrandonPlaster. All rights reserved.
//

#import "BufferProcessor.h"
#import <UIKit/UIKit.h>

@implementation BufferProcessor

// Hough Circle Detector
// Notes:   Assumes you've already allocated memory for destination
//          Assumes the source is edges
+ (int) detectCircles: (vImage_Buffer *)source withRadius:(int)radius useGradient:(BOOL) useGradient outputHough:(vImage_Buffer *)hough{
    
    // TODO: What is the number of points based on?
    int votingThreshold = MAX(30, radius);
    unsigned char *srcAddress = source->data;    
    unsigned char *houghAddress = hough->data;
    
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
            // Make hough image visible
            if (houghAddress[pixel] > 0) {
                houghAddress[pixel] += 30;
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

+ (void)colorQuantization: (vImage_Buffer *)src toDestination: (vImage_Buffer*)dst withMeans:(int)k andMethod: (ImageType) type {
    switch (type) {
        case RGB:{
            [self kMeans:k forRGBImage:src toDestination:dst];
            break;
        }
        case HSV:{
            size_t height = src->height;
            size_t width = src->width;
            size_t bytesPerRow = 3*width;
            unsigned char* hsvAddress = malloc(height*bytesPerRow);
            vImage_Buffer hsv = { hsvAddress, height, width, bytesPerRow };
            
            [self convertRGBImage:src toHSVDestination:&hsv];
            [self kMeans:k forHSVImage:&hsv toDestination:&hsv];
            [self convertHSVImage:&hsv toRGBDestination:dst];
            free(hsvAddress);
            break;
        }
        default:
            break;
    }
}

+ (void)kMeans: (int)k forRGBImage: (vImage_Buffer *)src toDestination: (vImage_Buffer *)dst{
    int kMeans[k][3], kPoints[k], steps = 5, step = 0, meanIndex = 0, r, g, b;
    float minDistance = 1000, distance;
    unsigned char* srcAddress = src->data;
    unsigned char* dstAddress = dst->data;

    unsigned long kSums[k][3], pixel;
    
    // Initial random values
    for (int i = 0; i < k; i++) {
        
        kMeans[i][0] = arc4random()%256;
        kMeans[i][1] = arc4random()%256;
        kMeans[i][2] = arc4random()%256;
        kSums[i][0] = 0;
        kSums[i][1] = 0;
        kSums[i][2] = 0;
        kPoints[i] = 0;
        NSLog(@"Kmean: %i, %i, %i", kMeans[i][0], kMeans[i][1],kMeans[i][2]);
    }
    
    while (step < steps) {
        // Iterate through points
        for (int row = 0; row < src->height; row++) {
            for (int column = 0; column < src->width; column++) {
                pixel = row*src->rowBytes + 4*column;
                r = srcAddress[pixel];
                g = srcAddress[pixel + 1];
                b = srcAddress[pixel + 2];
                
                // Determine closest cluster
                minDistance = 1000;
                for (int i = 0; i < k; i++) {
                    distance = sqrt(pow(kMeans[i][0] - r, 2) + pow(kMeans[i][1] - g, 2) + pow(kMeans[i][2] - b, 2));
                    if (distance < minDistance) {
                        minDistance = distance;
                        meanIndex = i;
                    }
                }
                kSums[meanIndex][0] += r;
                kSums[meanIndex][1] += g;
                kSums[meanIndex][2] += b;
                kPoints[meanIndex]++;
            }
        }
        
        // Calculate new k-means
        for (int i = 0; i < k; i++) {
            kMeans[i][0] = (int)kSums[i][0]/kPoints[i];
            kMeans[i][1] = (int)kSums[i][1]/kPoints[i];
            kMeans[i][2] = (int)kSums[i][2]/kPoints[i];
            kSums[i][0] = 0;
            kSums[i][1] = 0;
            kSums[i][2] = 0;
            kPoints[i] = 0;
            NSLog(@"Kmean Iteration [%i]: %i, %i, %i", step, kMeans[i][0], kMeans[i][1],kMeans[i][2]);
        }
        step++;
    }
    
    // Replace with new means
    for (int row = 0; row < src->height; row++) {
        for (int column = 0; column < src->width; column++) {
            pixel = row*src->rowBytes + 4*column;
            r = srcAddress[pixel];
            g = srcAddress[pixel + 1];
            b = srcAddress[pixel + 2];
            
            // Determine closest cluster
            minDistance = 1000;
            for (int i = 0; i < k; i++) {
                distance = sqrt(pow(kMeans[i][0] - r, 2) + pow(kMeans[i][1] - g, 2) + pow(kMeans[i][2] - b, 2));
                if (distance < minDistance) {
                    minDistance = distance;
                    meanIndex = i;
                }
            }
            dstAddress[pixel] = kMeans[meanIndex][0];
            dstAddress[pixel + 1] = kMeans[meanIndex][1];
            dstAddress[pixel + 2] = kMeans[meanIndex][2];
        }
    }
}

+ (void)kMeans: (int)k forHSVImage: (vImage_Buffer *)src toDestination: (vImage_Buffer *)dst{
    int kMeans[k], kPoints[k], steps = 5, step = 0, meanIndex = 0, h;
    float minDistance = 1000, distance;
    unsigned char* srcAddress = src->data;
    unsigned char* dstAddress = dst->data;
    
    unsigned long kSums[k], pixel;
    
    // Initial random values
    for (int i = 0; i < k; i++) {
        
        kMeans[i] = arc4random()%360;
        kSums[i] = 0;
        kPoints[i] = 0;
        NSLog(@"Kmean: %i", kMeans[i]);
    }
    
    while (step < steps) {
        // Iterate through points
        for (int row = 0; row < src->height; row++) {
            for (int column = 0; column < src->width; column++) {
                pixel = row*src->rowBytes + 3*column;
                h = srcAddress[pixel];
                
                // Determine closest cluster
                minDistance = 1000;
                for (int i = 0; i < k; i++) {
                    distance = ABS(kMeans[i] - h);
                    if (distance < minDistance) {
                        minDistance = distance;
                        meanIndex = i;
                    }
                }
                kSums[meanIndex] += h;
                kPoints[meanIndex]++;
            }
        }
        
        // Calculate new k-means
        for (int i = 0; i < k; i++) {
            kMeans[i] = (int)kSums[i]/kPoints[i];
            kSums[i] = 0;
            kPoints[i] = 0;
            NSLog(@"Kmean Iteration [%i]: %i", step, kMeans[i]);
        }
        step++;
    }
    
    // Replace with new means
    for (int row = 0; row < src->height; row++) {
        for (int column = 0; column < src->width; column++) {
            pixel = row*src->rowBytes + 3*column;
            h = srcAddress[pixel];
            
            // Determine closest cluster
            minDistance = 1000;
            for (int i = 0; i < k; i++) {
                distance = ABS(kMeans[i] - h);
                if (distance < minDistance) {
                    minDistance = distance;
                    meanIndex = i;
                }
            }
            dstAddress[pixel] = kMeans[meanIndex];
            dstAddress[pixel + 1] = srcAddress[pixel + 1];
            dstAddress[pixel + 2] = srcAddress[pixel + 2];
        }
    }
}


+ (void)convertRGBImage: (vImage_Buffer *)src toHSVDestination: (vImage_Buffer *)dst {
    unsigned char * srcAddress = src->data;
    unsigned char * dstAddress = dst->data;
    CGFloat h = 0, s, v, r, g, b, a;
    UIColor *color;
    unsigned long rgbaPixel, hsvPixel;
    for (int row = 0; row < src->height; row++) {
        for (int column = 0; column < src->width; column++) {
            rgbaPixel = row*src->rowBytes + 4*column;
            hsvPixel = row*dst->rowBytes + 3*column;

            r = (CGFloat)srcAddress[rgbaPixel]/255.;
            g = (CGFloat)srcAddress[rgbaPixel + 1]/255.;
            b = (CGFloat)srcAddress[rgbaPixel + 2]/255.;
            
            color = [UIColor colorWithRed:r green:g blue:b alpha:1.0];
            [color getHue:&h saturation:&s brightness:&v alpha:&a];
            

            // Set values
            dstAddress[hsvPixel] = (int)100*h;
            dstAddress[hsvPixel + 1] = (int)100*s;
            dstAddress[hsvPixel + 2] = (int)100*v;
        }
    }
}

+ (void)convertHSVImage: (vImage_Buffer *)src toRGBDestination: (vImage_Buffer *)dst {
    unsigned char * srcAddress = src->data;
    unsigned char * dstAddress = dst->data;
    CGFloat h, s, v, r = 0, g = 0, b = 0, a = 1;
    UIColor *color;
    unsigned long rgbaPixel, hsvPixel;
    for (int row = 0; row < src->height; row++) {
        for (int column = 0; column < src->width; column++) {
            hsvPixel = row*src->rowBytes + 3*column;
            rgbaPixel = row*dst->rowBytes + 4*column;

            h = (CGFloat)srcAddress[hsvPixel]/100;
            s = (CGFloat)srcAddress[hsvPixel + 1]/100;
            v = (CGFloat)srcAddress[hsvPixel + 2]/100;
            
            color = [UIColor colorWithHue:h saturation:s brightness:v alpha:a];
            [color getRed:&r green:&g blue:&b alpha:&a];
    
            // Set values
            dstAddress[rgbaPixel] = (int)255*r;
            dstAddress[rgbaPixel + 1] = (int)255*g;
            dstAddress[rgbaPixel + 2] = (int)255*b;
        }
    }
}


@end