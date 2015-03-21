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

// TODO: Fix location
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
    CGImageRef imageRef = [self.image CGImage];
    NSUInteger width = CGImageGetWidth(imageRef);
    NSUInteger height = CGImageGetHeight(imageRef);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
    NSUInteger bytesPerRow = width*sizeof(unsigned char);
    NSUInteger bitsPerComponent = 8;
    unsigned char *srcAddress = (unsigned char*) malloc(height * bytesPerRow);
    unsigned char *dstAddress = (unsigned char*) malloc(height * bytesPerRow);
    vImage_Buffer src = { srcAddress, height, width, bytesPerRow };
    vImage_Buffer dst = { dstAddress, height, width, bytesPerRow };

    // Copy original image into buffer
    CGContextRef context = CGBitmapContextCreate(srcAddress, width, height,
                                                 bitsPerComponent, bytesPerRow,
                                                 colorSpace, kCGImageAlphaNone);
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
    CGContextRelease(context);
    
    // Do processing on buffer
    [BufferProcessor cannyDetector:&src toDestination:&dst withMinVal:self.maxThresholdSlider.value*(2./3.) andMaxVal:self.maxThresholdSlider.value];
    int total = [BufferProcessor detectCircles:&dst withRadius:self.radiusSlider.value useGradient:NO];
    NSLog(@"Found %i circles",total);
    free(srcAddress);

    // Create new image
    CGContextRef newContext = CGBitmapContextCreate(dstAddress, width, height,
                                                 bitsPerComponent, bytesPerRow,
                                                 colorSpace, kCGImageAlphaNone);
    CGImageRef newImageRef = CGBitmapContextCreateImage(newContext);
    CGContextRelease(newContext);
    free(dstAddress);
    CGColorSpaceRelease(colorSpace);

    // Display the image
    [self.view.layer setContents: (__bridge id)newImageRef];

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
