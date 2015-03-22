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

+ (void) cannyDetector: (vImage_Buffer *)source toDestination: (vImage_Buffer *)destination withMinVal:(int)minVal andMaxVal:(int)maxVal;

+ (int) detectCircles: (vImage_Buffer *)source withRadius:(int)radius useGradient:(BOOL) useGradient outputHough:(vImage_Buffer *)hough;


@end
