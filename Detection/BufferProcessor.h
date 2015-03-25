//
//  BufferProcessor.h
//  Detection
//
//  Created by Brandon Plaster on 3/18/15.
//  Copyright (c) 2015 BrandonPlaster. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Accelerate/Accelerate.h>

@interface BufferProcessor : NSObject

typedef enum {
    RGB,
    HSV
} ImageType;

+ (void) cannyDetector: (vImage_Buffer *)source toDestination: (vImage_Buffer *)destination withMinVal:(int)minVal andMaxVal:(int)maxVal;

+ (int) detectCircles: (vImage_Buffer *)source withRadius:(int)radius outputHough:(vImage_Buffer *)hough;

+ (void)colorQuantization: (vImage_Buffer *)src toDestination: (vImage_Buffer*)dst withMeans:(int)k andMethod: (ImageType) type ;

+ (void)convertRGBImage: (vImage_Buffer *)src toHSVDestination: (vImage_Buffer *)dst;

+ (void)convertHSVImage: (vImage_Buffer *)src toRGBDestination: (vImage_Buffer *)dst;

+ (long long)ssdOfImage: (vImage_Buffer *)image1 andImage: (vImage_Buffer *)image2;

+ (int*) hueHistogramFor: (vImage_Buffer *)src toDest:(int*)histogram;


@end
