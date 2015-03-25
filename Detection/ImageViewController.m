//
//  ImageViewController.m
//  Detection
//
//  Created by Brandon Plaster on 3/17/15.
//  Copyright (c) 2015 BrandonPlaster. All rights reserved.
//

#import "ImageViewController.h"
#import "HistViewController.h"
#import "BufferProcessor.h"

@interface ImageViewController () <UINavigationControllerDelegate, UIImagePickerControllerDelegate>

@property (nonatomic, strong) UISlider *maxThresholdSlider;
@property (nonatomic, strong) UISlider *radiusSlider;
@property (nonatomic, strong) UIImageView *topImageView;
@property (nonatomic, strong) UIImageView *bottomImageView;
@property (strong, nonatomic) IBOutlet UISegmentedControl *modeSegmentController;
@property (strong, nonatomic) IBOutlet UISegmentedControl *colorSegmentController;
@property (nonatomic, assign) ImageType currentImageMode;
@property (strong, nonatomic) IBOutlet UIStepper *stepperController;
@property (strong, nonatomic) IBOutlet UISwitch *gradientSwitch;
@property (strong, nonatomic) HistViewController *histView;
@property (strong, nonatomic) IBOutlet UIButton *histogramButton;

@property (nonatomic, assign) CGSize screenSize;

@end

@implementation ImageViewController

- (id) initWithImage: (UIImage *) image {
    if ((self = [super init])) {
        self.image = image;
    }
    return self;
}

-(BOOL)shouldAutorotate {
    return NO;
}

-(NSUInteger)supportedInterfaceOrientations{
    return UIInterfaceOrientationPortrait;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    self.currentImageMode = HSV;
    self.screenSize = ([UIScreen mainScreen]).bounds.size;
    self.topImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, self.screenSize.width, self.screenSize.height/2)];
    self.bottomImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, self.screenSize.height/2, self.screenSize.width, self.screenSize.height/2)];
    [self.view insertSubview:self.topImageView atIndex:0];
    [self.view insertSubview:self.bottomImageView atIndex:0];
    
    // Max threshold for Canny
    self.maxThresholdSlider = [[UISlider alloc] initWithFrame:CGRectMake(0, 0, 200, 30)];
    CGAffineTransform trans = CGAffineTransformMakeRotation(M_PI * -0.5);
    self.maxThresholdSlider.transform = trans;
    self.maxThresholdSlider.maximumValue = 255;
    self.maxThresholdSlider.value = 60;
    [self.maxThresholdSlider addTarget:self action:@selector(sliderValueChanged:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.maxThresholdSlider];
    
    // Radius slider for circles
    self.radiusSlider = [[UISlider alloc] initWithFrame:CGRectMake(0, 0, 200, 30)];
    self.radiusSlider.transform = trans;
    self.radiusSlider.maximumValue = 100;
    self.radiusSlider.value = 50;
    [self.radiusSlider addTarget:self action:@selector(sliderValueChanged:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.radiusSlider];
    
    // Create histogram view
    self.histView = [[HistViewController alloc] init];
    
    // Add gesture
    UITapGestureRecognizer *gesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleNavBar:)];
    [self.view addGestureRecognizer:gesture];
    [self.navigationController setNavigationBarHidden:YES animated:YES];
    
    // Update Views
    [self.maxThresholdSlider setHidden:NO];
    [self.radiusSlider setHidden:NO];
    [self.stepperController setHidden:YES];
    [self.colorSegmentController setHidden:YES];
    [self.maxThresholdSlider setHidden:!self.gradientSwitch.isOn];
    [self.histogramButton setHidden:YES];
    [self updateViewPositions];
    [self refreshImageView];
}

- (void)toggleNavBar:(UITapGestureRecognizer *)gesture {
    BOOL barsHidden = self.navigationController.navigationBar.hidden;
    [self.navigationController setNavigationBarHidden:!barsHidden animated:YES];
}

- (void) updateViewPositions {
    int padding = 10;

    self.maxThresholdSlider.center = CGPointMake(self.bottomImageView.center.x + self.bottomImageView.bounds.size.width/2 - self.maxThresholdSlider.bounds.size.height/2 - padding, self.bottomImageView.center.y);
    self.radiusSlider.center = CGPointMake(self.topImageView.center.x + self.topImageView.bounds.size.width/2 - self.radiusSlider.bounds.size.height/2 - padding, self.topImageView.center.y);
}

- (void) sliderValueChanged:(id)sender {
    [self refreshImageView];
}

- (void)refreshImageView {
    
    switch (self.modeSegmentController.selectedSegmentIndex) {
        
        // Circle Detection
        case 0:{
            
            // Info for original image
            CGImageRef imageRef = [self.image CGImage];
            NSUInteger width = CGImageGetWidth(imageRef);
            NSUInteger height = CGImageGetHeight(imageRef);
            CGColorSpaceRef graySpace = CGColorSpaceCreateDeviceGray();
            NSUInteger bytesPerRow = width*sizeof(unsigned char);
            NSUInteger bitsPerComponent = 8;
            unsigned char *srcAddress = (unsigned char*) malloc(height * bytesPerRow);
            unsigned char *dstAddress = (unsigned char*) malloc(height * bytesPerRow);
            vImage_Buffer src = { srcAddress, height, width, bytesPerRow };
            vImage_Buffer dst = { dstAddress, height, width, bytesPerRow };
            
            // Copy original image into buffer
            CGContextRef context = CGBitmapContextCreate(srcAddress, width, height,
                                                         bitsPerComponent, bytesPerRow,
                                                         graySpace, kCGImageAlphaNone);
            CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
            CGContextRelease(context);
            
            // Hough space
            int radius = self.radiusSlider.value;
            size_t houghRowBytes = 2*radius+bytesPerRow;
            size_t houghHeight = 2*radius+height;
            size_t houghWidth = 2*radius + width;
            unsigned char *houghAddress = calloc(houghRowBytes*houghHeight, 1);
            vImage_Buffer hough = {houghAddress, houghHeight, houghWidth, houghRowBytes};
            
            // Do processing on buffer
            if (self.gradientSwitch.isOn) {
                [BufferProcessor cannyDetector:&src toDestination:&dst withMinVal:self.maxThresholdSlider.value*(3./4.) andMaxVal:self.maxThresholdSlider.value];
            } else {
                [BufferProcessor cannyDetector:&src toDestination:&dst withMinVal:0 andMaxVal:0];
            }
            
            int total = [BufferProcessor detectCircles:&dst withRadius:radius outputHough:&hough];
            NSLog(@"Found %i circles of radius %i",total, radius);
            free(srcAddress);
            
            // Create new image
            CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
            unsigned char *newAddress = (unsigned char*) malloc(4 * height * bytesPerRow);
            
            CGContextRef newContext = CGBitmapContextCreate(newAddress, width, height,
                                                            bitsPerComponent, 4*bytesPerRow,
                                                            colorSpace, kCGImageAlphaNoneSkipLast | kCGBitmapByteOrder32Big);
            CGContextDrawImage(newContext, CGRectMake(0, 0, width, height), imageRef);
            
            // Overlay circles onto original image
            unsigned long grayPixel = 0, colorPixel = 0;
            for (int row = 0; row < height; row++) {
                for (int column = 0; column < width; column++) {
                    grayPixel = row * bytesPerRow + column;
                    colorPixel = 4 * (row * bytesPerRow + column);
                    if (dstAddress[grayPixel]) {
                        newAddress[colorPixel] = 255;
                        newAddress[colorPixel+1] = 255;
                        newAddress[colorPixel+2] = 255;
                    }
                }
            }
            
            CGImageRef newImageRef = CGBitmapContextCreateImage(newContext);
            CGContextRelease(newContext);
            free(dstAddress);
            free(newAddress);
            
            // Create Hough image
            CGContextRef houghContext = CGBitmapContextCreate(houghAddress, houghWidth, houghHeight,
                                                              bitsPerComponent, houghRowBytes,
                                                              graySpace, kCGImageAlphaNone);
            CGImageRef houghImageRef = CGBitmapContextCreateImage(houghContext);
            CGContextRelease(houghContext);
            free(houghAddress);
            
            // Free colorspace
            CGColorSpaceRelease(colorSpace);
            CGColorSpaceRelease(graySpace);
            
            // Display the image
            [self.bottomImageView setImage:[UIImage imageWithCGImage:houghImageRef]];
            [self.topImageView setImage:[UIImage imageWithCGImage:newImageRef]];
            
            // Release images
            CGImageRelease(houghImageRef);
            CGImageRelease(newImageRef);
            
            break;
        }
            
        // Color Quantization
        case 1:{
            
            // Info for original image
            CGImageRef imageRef = [self.image CGImage];
            NSUInteger width = CGImageGetWidth(imageRef);
            NSUInteger height = CGImageGetHeight(imageRef);
            NSUInteger bytesPerRow = 4*width*sizeof(unsigned char);
            NSUInteger bitsPerComponent = 8;
            unsigned char *srcAddress = (unsigned char*) malloc(height * bytesPerRow);
            unsigned char *dstAddress = (unsigned char*) malloc(height * bytesPerRow);
            vImage_Buffer src = { srcAddress, height, width, bytesPerRow };
            vImage_Buffer dst = { dstAddress, height, width, bytesPerRow };
            
            // Set image to buffer
            CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
            
            CGContextRef context = CGBitmapContextCreate(srcAddress, width, height,
                                                            bitsPerComponent, bytesPerRow,
                                                            colorSpace, kCGImageAlphaNoneSkipLast | kCGBitmapByteOrder32Big);
            CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
            CGContextRelease(context);
            
            // Do quantization
            NSLog(@"k-means: %i", (int)self.stepperController.value);
            [BufferProcessor colorQuantization:&src toDestination:&dst withMeans:(int)self.stepperController.value andMethod: self.currentImageMode];
            long long diff = [BufferProcessor ssdOfImage:&src andImage:&dst];
            NSLog(@"SSD: %lli", diff);
            
            // Set up histograms
            [self.histView setImageHistogramOriginal:&src andQuantized:&dst];
            
            //Create new image
            CGContextRef newContext = CGBitmapContextCreate(dstAddress, width, height,
                                                              bitsPerComponent, bytesPerRow,
                                                              colorSpace, kCGImageAlphaNoneSkipLast | kCGBitmapByteOrder32Big);
            
            CGImageRef newImageRef = CGBitmapContextCreateImage(newContext);
            CGContextRelease(newContext);
            free(srcAddress);
            free(dstAddress);

            [self.bottomImageView setImage:[UIImage imageWithCGImage:newImageRef]];
            [self.topImageView setImage:self.image];

            break;
        }
            
        default:
            break;
    }

}

- (IBAction)changeImagePressed:(id)sender {
    UIImagePickerController *pickerController = [UIImagePickerController new];
    pickerController.delegate = self;
    [self presentViewController:pickerController animated:YES completion:nil];
}

- (IBAction)segmentChanged:(id)sender {
    UISegmentedControl *control = (UISegmentedControl *)sender;
    if (control == self.modeSegmentController) {
        switch (control.selectedSegmentIndex) {
            case 0:{
                [self.radiusSlider setHidden:NO];
                [self.stepperController setHidden:YES];
                [self.colorSegmentController setHidden:YES];
                [self.gradientSwitch setHidden:NO];
                [self.maxThresholdSlider setHidden:!self.gradientSwitch.isOn];
                [self.histogramButton setHidden:YES];
                break;
            }
            case 1:{
                [self.radiusSlider setHidden:YES];
                [self.stepperController setHidden:NO];
                [self.colorSegmentController setHidden:NO];
                [self.gradientSwitch setHidden:YES];
                [self.maxThresholdSlider setHidden:YES];
                [self.histogramButton setHidden:NO];
                break;
            }
                
            default:
                break;
        }

    } else if(control == self.colorSegmentController){
        switch (control.selectedSegmentIndex) {
            case 0:{
                self.currentImageMode = RGB;
                break;
            }
            case 1:{
                self.currentImageMode = HSV;
                break;
            }
                
            default:
                break;
        }
        
    }
    [self refreshImageView];

}

- (IBAction)stepperChanged:(id)sender {
    [self refreshImageView];
}

- (IBAction)gradientSwitchChanged:(id)sender {
    [self.maxThresholdSlider setHidden:!self.gradientSwitch.isOn];
    [self refreshImageView];
}

- (IBAction)histogramButtonPressed:(id)sender {
    [self.navigationController pushViewController:self.histView animated:YES];
}

#pragma mark - UIImagePickerControllerDelegate

- (void) imagePickerController:(UIImagePickerController *)picker
         didFinishPickingImage:(UIImage *)image
                   editingInfo:(NSDictionary *)editingInfo
{
    [self dismissModalViewControllerAnimated:YES];
    self.image = image;
    [self refreshImageView];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
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
