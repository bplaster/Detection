//
//  ImageViewController.m
//  Detection
//
//  Created by Brandon Plaster on 3/17/15.
//  Copyright (c) 2015 BrandonPlaster. All rights reserved.
//

#import "ImageViewController.h"
#import "BufferProcessor.h"

@interface ImageViewController () <UINavigationControllerDelegate, UIImagePickerControllerDelegate>

@property (nonatomic, strong) UISlider *maxThresholdSlider;
@property (nonatomic, strong) UISlider *radiusSlider;
@property (nonatomic, strong) UIImageView *topImageView;
@property (nonatomic, strong) UIImageView *bottomImageView;

@property (nonatomic, assign) CGSize screenSize;

@end

@implementation ImageViewController

- (id) initWithImage: (UIImage *) image {
    if ((self = [super init])) {
        self.image = image;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
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
    
    [self updateViewPositions];
    [self refreshImageView];
}

- (void) updateViewPositions {
    int padding = 10;
    self.maxThresholdSlider.center = CGPointMake(self.screenSize.width - self.maxThresholdSlider.bounds.size.height/2 - padding, self.screenSize.height/2 - self.maxThresholdSlider.bounds.size.width/2 - padding);
    self.radiusSlider.center = CGPointMake(self.screenSize.width - self.maxThresholdSlider.bounds.size.height/2 - padding, self.screenSize.height/2 + self.maxThresholdSlider.bounds.size.width/2 - padding);
}

- (void) sliderValueChanged:(id)sender {
    [self refreshImageView];
}

- (void)refreshImageView {
    
    // Info for original image
    [self.topImageView setImage: self.image];
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
    [BufferProcessor cannyDetector:&src toDestination:&dst withMinVal:self.maxThresholdSlider.value*(2./3.) andMaxVal:self.maxThresholdSlider.value];
    int total = [BufferProcessor detectCircles:&dst withRadius:radius useGradient:NO outputHough:&hough];
    NSLog(@"Found %i circles",total);
    free(srcAddress);
    
    // Create new image
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    unsigned char *newAddress = (unsigned char*) malloc(4 * height * bytesPerRow);

    CGContextRef newContext = CGBitmapContextCreate(newAddress, width, height,
                                                 bitsPerComponent, 4*bytesPerRow,
                                                 colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
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
//    [self.view.layer setContents: (__bridge id)newImageRef];

}

- (IBAction)changeImagePressed:(id)sender {
    UIImagePickerController *pickerController = [UIImagePickerController new];
    pickerController.delegate = self;
    [self presentViewController:pickerController animated:YES completion:nil];
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
