//
//  HistViewController.h
//  Detection
//
//  Created by Brandon Plaster on 3/24/15.
//  Copyright (c) 2015 BrandonPlaster. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CorePlot-CocoaTouch.h"
#import <Accelerate/Accelerate.h>

@interface HistViewController : UIViewController <CPTBarPlotDataSource, CPTBarPlotDelegate>

@property (nonatomic, strong) IBOutlet CPTGraphHostingView *hostView;
@property (nonatomic, strong) CPTBarPlot *originalPlot;
@property (nonatomic, strong) CPTBarPlot *quantizedPlot;
@property (nonatomic, strong) CPTPlotSpaceAnnotation *annotation;

-(void)initPlot;
-(void)configureGraph;
-(void)configurePlots;
-(void)configureAxes;

-(void)setImageHistogramOriginal: (vImage_Buffer*) original andQuantized: (vImage_Buffer*)quantized;

@end
