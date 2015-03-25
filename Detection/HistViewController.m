//
//  HistViewController.m
//  Detection
//
//  Created by Brandon Plaster on 3/24/15.
//  Copyright (c) 2015 BrandonPlaster. All rights reserved.
//
// Used Tutorial: http://www.raywenderlich.com/13271/how-to-draw-graphs-with-core-plot-part-2

#import "HistViewController.h"
#import "BufferProcessor.h"

@interface HistViewController ()

@end

@implementation HistViewController

CGFloat const CPDBarWidth = 0.25f;
CGFloat const CPDBarInitialX = 0.25f;
int* originalHistogram;
int* quantizedHistogram;

#pragma mark - UIViewController lifecycle methods

- (id)init {
    if (self = [super init]) {
        originalHistogram = valloc(100);
        quantizedHistogram = valloc(100);
    }
    return self;
}

-(void)viewDidLoad {
    [super viewDidLoad];
    [self initPlot];
    
    // Add gesture
    UITapGestureRecognizer *gesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleNavBar:)];
    [self.view addGestureRecognizer:gesture];
    [self.navigationController setNavigationBarHidden:YES animated:YES];
}

- (void)toggleNavBar:(UITapGestureRecognizer *)gesture {
    BOOL barsHidden = self.navigationController.navigationBar.hidden;
    [self.navigationController setNavigationBarHidden:!barsHidden animated:YES];
}

#pragma mark - Chart behavior
-(void)initPlot {
    self.hostView.allowPinchScaling = NO;
    [self configureGraph];
    [self configurePlots];
    [self configureAxes];
}

-(void)configureGraph {
    // 1 - Create the graph

    CPTGraph *graph = [[CPTXYGraph alloc] initWithFrame:self.hostView.bounds];
    graph.plotAreaFrame.masksToBorder = NO;
    self.hostView.hostedGraph = graph;
    
    // 2 - Configure the graph
    [graph applyTheme:[CPTTheme themeNamed:kCPTPlainBlackTheme]];
    graph.paddingBottom = 30.0f;
    graph.paddingLeft  = 30.0f;
    graph.paddingTop    = 30.0f;
    graph.paddingRight  = 30.0f;
    
    // 3 - Set up styles
    CPTMutableTextStyle *titleStyle = [CPTMutableTextStyle textStyle];
    titleStyle.color = [CPTColor whiteColor];
    titleStyle.fontName = @"Helvetica-Bold";
    titleStyle.fontSize = 16.0f;
    
    // 4 - Set up title
    NSString *title = @"Image Histograms";
    graph.title = title;
    graph.titleTextStyle = titleStyle;
    graph.titlePlotAreaFrameAnchor = CPTRectAnchorTop;
    graph.titleDisplacement = CGPointMake(0.0f, -16.0f);
    
    // 5 - Set up plot space
    CGFloat xMin = 0.0f;
    CGFloat xMax = 100.0f;
    CGFloat yMin = 0.0f;
    CGFloat yMax = 100.0f;  // TODO change
    CPTXYPlotSpace *plotSpace = (CPTXYPlotSpace *) graph.defaultPlotSpace;
    plotSpace.xRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromFloat(xMin) length:CPTDecimalFromFloat(xMax)];
    plotSpace.yRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromFloat(yMin) length:CPTDecimalFromFloat(yMax)];
}

-(void)configurePlots {
    // 1 - Set up the plots
    self.originalPlot = [CPTBarPlot tubularBarPlotWithColor:[CPTColor redColor] horizontalBars:NO];
    self.originalPlot.identifier = @"original";
    self.quantizedPlot = [CPTBarPlot tubularBarPlotWithColor:[CPTColor greenColor] horizontalBars:NO];
    self.quantizedPlot.identifier = @"quantized";
    
    // 2 - Set up line style
    CPTMutableLineStyle *barLineStyle = [[CPTMutableLineStyle alloc] init];
    barLineStyle.lineColor = [CPTColor lightGrayColor];
    barLineStyle.lineWidth = 0.5;
    
    // 3 - Add plots to graph
    CPTGraph *graph = self.hostView.hostedGraph;
    CGFloat barX = CPDBarInitialX;
    NSArray *plots = [NSArray arrayWithObjects:self.originalPlot, self.quantizedPlot, nil];
    for (CPTBarPlot *plot in plots) {
        plot.dataSource = self;
        plot.delegate = self;
        plot.barWidth = CPTDecimalFromDouble(CPDBarWidth);
        plot.barOffset = CPTDecimalFromDouble(barX);
        plot.lineStyle = barLineStyle;
        [graph addPlot:plot toPlotSpace:graph.defaultPlotSpace];
        barX += CPDBarWidth;
    }
}

-(void)configureAxes {
    // 1 - Configure styles
    CPTMutableTextStyle *axisTitleStyle = [CPTMutableTextStyle textStyle];
    axisTitleStyle.color = [CPTColor whiteColor];
    axisTitleStyle.fontName = @"Helvetica-Bold";
    axisTitleStyle.fontSize = 12.0f;
    CPTMutableLineStyle *axisLineStyle = [CPTMutableLineStyle lineStyle];
    axisLineStyle.lineWidth = 2.0f;
    axisLineStyle.lineColor = [[CPTColor whiteColor] colorWithAlphaComponent:1];
    
    // 2 - Get the graph's axis set
    CPTXYAxisSet *axisSet = (CPTXYAxisSet *) self.hostView.hostedGraph.axisSet;
    // 3 - Configure the x-axis
    axisSet.xAxis.labelingPolicy = CPTAxisLabelingPolicyNone;
    axisSet.xAxis.title = @"Hue Value";
    axisSet.xAxis.titleTextStyle = axisTitleStyle;
    axisSet.xAxis.titleOffset = 10.0f;
    axisSet.xAxis.axisLineStyle = axisLineStyle;
    
    // 4 - Configure the y-axis
    axisSet.yAxis.labelingPolicy = CPTAxisLabelingPolicyNone;
    axisSet.yAxis.title = @"Count";
    axisSet.yAxis.titleTextStyle = axisTitleStyle;
    axisSet.yAxis.titleOffset = 5.0f;
    axisSet.yAxis.axisLineStyle = axisLineStyle;
}

-(void)setImageHistogramOriginal: (vImage_Buffer*) original andQuantized: (vImage_Buffer*)quantized {

    // Set up histograms
    size_t height = original->height;
    size_t width = original->width;
    size_t bytesPerRow = 3*width;
    unsigned char* hsvAddress = malloc(height*bytesPerRow);
    vImage_Buffer hsv = { hsvAddress, height, width, bytesPerRow };
    
    [BufferProcessor convertRGBImage:original toHSVDestination:&hsv];
    [BufferProcessor hueHistogramFor:&hsv toDest:originalHistogram];
    [BufferProcessor convertRGBImage:quantized toHSVDestination:&hsv];
    [BufferProcessor hueHistogramFor:&hsv toDest:quantizedHistogram];
    
    free(hsvAddress);
    [self.originalPlot reloadData];
    [self.quantizedPlot reloadData];
    
}

#pragma mark - CPTPlotDataSource methods

-(NSUInteger)numberOfRecordsForPlot:(CPTPlot *)plot {
    return 100;
}

-(NSNumber *)numberForPlot:(CPTPlot *)plot field:(NSUInteger)fieldEnum recordIndex:(NSUInteger)index {
    int value = 0;
    if ([plot.identifier isEqual: @"original"]) {
        value = originalHistogram[index];
    } else if ([plot.identifier isEqual: @"quantized"]) {
        value = quantizedHistogram[index];
    }
    return [NSDecimalNumber numberWithInt:value];
}

#pragma mark - CPTBarPlotDelegate methods
-(void)barPlot:(CPTBarPlot *)plot barWasSelectedAtRecordIndex:(NSUInteger)index {
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
    
}

- (void) dealloc {
    free(originalHistogram);
    free(quantizedHistogram);
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
