//
//  ViewController.m
//  Detection
//
//  Created by Brandon Plaster on 3/6/15.
//  Copyright (c) 2015 BrandonPlaster. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <Accelerate/Accelerate.h>
#import "ViewController.h"

typedef enum {
    VFRecordingStateUnknown,
    VFRecordingStateRecording,
    VFRecordingStateFinished
} VFRecordingState;

@interface ViewController () <AVCaptureFileOutputRecordingDelegate, AVCaptureVideoDataOutputSampleBufferDelegate>

// Views
@property (strong, nonatomic) UISlider *maxThresholdSlider;
@property (strong, nonatomic) UISlider *minThresholdSlider;
@property (strong, nonatomic) IBOutlet UIButton *recordButton;
@property (nonatomic, strong) CALayer *previewLayer;

//@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;

// Variables
@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureMovieFileOutput *movieFileOutput;
@property (nonatomic, strong) AVCaptureVideoDataOutput *videoOutput;
@property (nonatomic, strong) AVAssetWriter *assetWriter;
@property (nonatomic, strong) AVAssetWriterInput *assetWriterInput;
@property (nonatomic, strong) AVAssetWriterInputPixelBufferAdaptor *assetWriterInputAdaptor;
@property (nonatomic, strong) dispatch_queue_t assetWritingQueue;
@property (nonatomic, strong) NSURL *fileURL;
@property (nonatomic, assign) VFRecordingState recordingState;
@property (nonatomic, assign) BOOL edgesEnabled;
@property (nonatomic, assign) BOOL assetWriterVideoInputReady;
@property (nonatomic, assign) uint8_t rotationState;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.edgesEnabled = NO;
    [self orientationChanged];
    
    // Setup layer for preview
    self.previewLayer = [CALayer layer];
    [self.previewLayer setFrame:self.view.bounds];
    [self.view.layer insertSublayer:self.previewLayer atIndex:0];
    
    self.maxThresholdSlider = [[UISlider alloc] initWithFrame:CGRectMake(0, 0, 200, 30)];
    self.minThresholdSlider = [[UISlider alloc] initWithFrame:CGRectMake(0, 0, 200, 30)];
    CGAffineTransform trans = CGAffineTransformMakeRotation(M_PI * -0.5);
    self.maxThresholdSlider.transform = trans;
    self.minThresholdSlider.transform = trans;
    self.maxThresholdSlider.maximumValue = 255;
    self.minThresholdSlider.maximumValue = 1.0;
    self.maxThresholdSlider.value = 60;
    self.minThresholdSlider.value = 0.8;
    self.maxThresholdSlider.hidden = YES;
    self.minThresholdSlider.hidden = YES;
    [self.view addSubview:self.maxThresholdSlider];
    [self.view addSubview:self.minThresholdSlider];
    
    [self updateViewPositions];
    
    // Setup capture session
    self.captureSession = [AVCaptureSession new];
    self.captureSession.sessionPreset = AVCaptureSessionPreset640x480;
    AVCaptureDevice *frontCamera;
    
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices) {
        if (device.position == AVCaptureDevicePositionFront) {
            frontCamera = device;
        }
    }
    
    AVCaptureDeviceInput *frontCaptureInput = [[AVCaptureDeviceInput alloc] initWithDevice:frontCamera error:nil];
    [self.captureSession addInput:frontCaptureInput];
    
    // Setup outputs
    self.videoOutput = [AVCaptureVideoDataOutput new];
//    [self.videoOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInteger:kCVPixelFormatType_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
    [self.videoOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInteger:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
    
    dispatch_queue_t videoDataDispatchQueue = dispatch_queue_create("edu.CS2049.videoDataOutputQueue", DISPATCH_QUEUE_SERIAL);
    [self.videoOutput setSampleBufferDelegate:self queue:videoDataDispatchQueue];
    [self.captureSession addOutput:self.videoOutput];
    
    self.fileURL = [[NSURL alloc] initFileURLWithPath:[NSString pathWithComponents:@[NSTemporaryDirectory(), @"myFilename.mp4"]]];
    
    [self createNewWriter];
    self.assetWritingQueue = dispatch_queue_create("edu.CS2049.assetWritingQueue", DISPATCH_QUEUE_SERIAL);
    
    // Detect orientation changes
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(orientationChanged)
                                                 name:UIDeviceOrientationDidChangeNotification
                                               object:nil];
    
    // Mirror the video
    AVCaptureConnection *videoConnection = nil;
    for (AVCaptureConnection *connection in self.videoOutput.connections) {
        for (AVCaptureInputPort *port in [connection inputPorts]) {
            if ([[port mediaType] isEqual:AVMediaTypeVideo] ) {
                videoConnection = connection;
                [videoConnection setVideoMirrored:YES];
                break;
            }
        }
        if (videoConnection) { break; }
    }

    // Start
    [self.captureSession startRunning];
}

-(void) createNewWriter{
    self.assetWriter = [[AVAssetWriter alloc] initWithURL:self.fileURL fileType:AVFileTypeQuickTimeMovie error:nil];
    self.assetWriterVideoInputReady = NO;
}

-(void) orientationChanged
{
    UIDeviceOrientation deviceOrientation = [UIDevice currentDevice].orientation;
    if (deviceOrientation == UIInterfaceOrientationPortraitUpsideDown){
        self.rotationState = 3;
    }
    
    else if (deviceOrientation == UIInterfaceOrientationPortrait){
        self.rotationState = 1;
    }
    
    else if (deviceOrientation == UIInterfaceOrientationLandscapeLeft){
        self.rotationState = 0;
    }
    
    else {
        self.rotationState = 2;
    }
    
    [self updateViewPositions];
}

- (void) updateViewPositions {
    int padding = 10;
    self.maxThresholdSlider.center = CGPointMake(self.view.bounds.size.width - self.maxThresholdSlider.bounds.size.height/2 - padding, self.view.bounds.size.height/2 - self.maxThresholdSlider.bounds.size.width/2 - padding);
    self.minThresholdSlider.center = CGPointMake(self.view.bounds.size.width - self.minThresholdSlider.bounds.size.height/2 - padding, self.view.bounds.size.height/2 + self.minThresholdSlider.bounds.size.width/2 + padding);

}

- (IBAction)toggleEdgeChanged:(id)sender {
    
    self.edgesEnabled = [((UISwitch *)sender) isOn];
    self.minThresholdSlider.hidden = ![((UISwitch *)sender) isOn];
    self.maxThresholdSlider.hidden = ![((UISwitch *)sender) isOn];

}

- (IBAction)recordButtonPressed:(id)sender {
    if (self.recordingState == VFRecordingStateRecording) {
        [self stopRecording];
    } else {
        [self.recordButton setTitle:@"Stop" forState:UIControlStateNormal];

        if ([[NSFileManager defaultManager] fileExistsAtPath:self.fileURL.path]) {
            [[NSFileManager defaultManager] removeItemAtURL:self.fileURL error:nil];
        }
        
        [self.movieFileOutput startRecordingToOutputFileURL:self.fileURL recordingDelegate:self];
        self.recordingState = VFRecordingStateRecording;
    }
}

- (IBAction)playButtonPressed:(id)sender {
    if (self.recordingState == VFRecordingStateRecording) {
        [self stopRecording];
    }
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:self.fileURL.path]) {
        MPMoviePlayerViewController *moviePlayerVC = [[MPMoviePlayerViewController alloc] initWithContentURL:self.fileURL];
        [self presentMoviePlayerViewControllerAnimated:moviePlayerVC];
        
        [[NSNotificationCenter defaultCenter] removeObserver:moviePlayerVC
                                                        name:MPMoviePlayerPlaybackDidFinishNotification
                                                      object:moviePlayerVC.moviePlayer];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(movieFinishedCallback:) name:MPMoviePlayerPlaybackDidFinishNotification object:[moviePlayerVC moviePlayer]];
    }
}

- (void)movieFinishedCallback:(NSNotification*)aNotification
{
    MPMoviePlayerController *moviePlayer = [aNotification object];
        
    // Remove this class from the observers
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:MPMoviePlayerPlaybackDidFinishNotification
                                                      object:moviePlayer];
        
    // Dismiss the view controller
    [self dismissMoviePlayerViewControllerAnimated];
    
    // TODO: Attempting to address Apple's memory leak on iPad... not quite working
    moviePlayer = NULL;
    
}

- (void) stopRecording {
    [self.recordButton setTitle:@"Record" forState:UIControlStateNormal];
    
    [self.movieFileOutput stopRecording];
    [self.assetWriter finishWritingWithCompletionHandler:^{
        [self createNewWriter];
    }];
    
    self.recordingState = VFRecordingStateFinished;
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegateMethods

- (void) captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    
    CVPixelBufferRef processedBuffer = [self processPixelBuffer:CMSampleBufferGetImageBuffer(sampleBuffer)];
    
    if (!self.assetWriterVideoInputReady) {
        self.assetWriterVideoInputReady = [self setupVideoInput:CMSampleBufferGetFormatDescription(sampleBuffer)];
    }
    
    switch (self.recordingState) {
        case VFRecordingStateFinished: {
            break;
        }
        case VFRecordingStateRecording: {
            if (self.assetWriter) {
                CMTime sampleTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);

                CVPixelBufferRetain(processedBuffer);
                dispatch_async(self.assetWritingQueue, ^{
                    if (self.assetWriter.status == AVAssetWriterStatusUnknown) {
                        if ([self.assetWriter startWriting]) {
                            [self.assetWriter startSessionAtSourceTime:sampleTime];
                        }
                    }
                    if (self.assetWriter.status == AVAssetWriterStatusWriting) {
                        if (self.assetWriterInput.isReadyForMoreMediaData) {
                            [self.assetWriterInputAdaptor appendPixelBuffer:processedBuffer withPresentationTime:sampleTime];
                        }
                    }
                    CVPixelBufferRelease(processedBuffer);
                });
            }
            break;
        }
        default:
            break;
    }
    CVPixelBufferRelease(processedBuffer);

}


- (CVPixelBufferRef) processPixelBuffer: (CVImageBufferRef) pixelBuffer {
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    
    size_t srcWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0);
    size_t srcHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0);
    size_t srcBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
    size_t dstHeight = srcHeight;
    size_t dstWidth = srcWidth;
    size_t dstBytesPerRow = srcBytesPerRow;
    
    if (self.rotationState == 1 || self.rotationState == 3) {
        dstHeight = srcWidth;
        dstWidth = srcHeight;
        dstBytesPerRow = dstWidth*sizeof(unsigned char);
    }
    
    unsigned char *srcAddress = (unsigned char *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
    unsigned char *tmpAddress = malloc(srcBytesPerRow*srcHeight);
    unsigned char *dstAddress = malloc(dstBytesPerRow*dstHeight);

    int bitsPerComponent = 8;
    
    vImage_Buffer src = { srcAddress, srcHeight, srcWidth, srcBytesPerRow };
    vImage_Buffer tmp = { tmpAddress, srcHeight, srcWidth, srcBytesPerRow };
    vImage_Buffer dst = { dstAddress, dstHeight, dstWidth, dstBytesPerRow };
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
    CGContextRef context;

    if (self.edgesEnabled) {
        [self cannyDetector:&src toDestination:&tmp withMinVal:self.minThresholdSlider.value*self.maxThresholdSlider.value andMaxVal:self.maxThresholdSlider.value];
    
    } else {
        vImageCopyBuffer(&src, &tmp, 1, kvImageNoFlags);
    }
    
    vImageRotate90_Planar8(&tmp, &dst, self.rotationState, 0, kvImageNoFlags);

    context = CGBitmapContextCreate(dstAddress, dstWidth, dstHeight, bitsPerComponent, dstBytesPerRow, colorSpace, kCGImageAlphaNone);
    CGImageRef imageRef = CGBitmapContextCreateImage(context);
    
    free(dstAddress);
    
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    
    // Display in view
    dispatch_sync(dispatch_get_main_queue(), ^{
        [self.view.layer setContents: (__bridge id)imageRef];
        CGImageRelease(imageRef);
    });
    
    // Create new pixel buffer
    CVPixelBufferRef processedBuffer = NULL;
    CVReturn status = CVPixelBufferCreateWithBytes(NULL, srcWidth, srcHeight, kCVPixelFormatType_OneComponent8, tmpAddress, srcBytesPerRow, pixelBufferReleaseCallback, NULL, NULL, &processedBuffer);
   
//    free(tmpAddress);


    return processedBuffer;
    
}

void pixelBufferReleaseCallback (void *releaseRefCon, const void *baseAddress)
{
    free((void *)baseAddress);
}

// Canny edge detector
// Notes:   Assumes you've already allocated memory for destination
//          Assumes 1 byte per pixel
- (void) cannyDetector: (vImage_Buffer *)source toDestination: (vImage_Buffer *)destination withMinVal:(int)minVal andMaxVal:(int)maxVal {
    
    unsigned char *destAddress = (unsigned char *)destination->data;
    size_t arraySize = source->rowBytes*source->height;
    
    // Gaussian
    const int16_t gaussKernel[25] = {2,4,5,4,2,4,9,12,9,4,5,12,15,12,5,4,9,12,9,4,2,4,5,4,2};
    vImageConvolve_Planar8(source, destination, NULL, 0, 0, gaussKernel, 5, 5, 115, 0, kvImageEdgeExtend);
    
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
    unsigned long pixel = 0;
    for (int row = 0; row < source->height; row++) {
        for (int column = 0; column < source->width; column++) {
            pixel = row*source->rowBytes + column;
            magAddress[pixel] = sqrtf(powf(gxAddress[pixel], 2)+powf(gyAddress[pixel], 2)); // Could approximate by abs(gx) + abs(gy)
        }
    }

    // Non-maximal suppression && Double threshold
    // TODO: need to handle border
    int value = 0;
//    int weakValue = 100;
    int strongValue = 255;
    for (int row = 1; row < source->height-1; row++) {
        for (int column = 1; column < source->width-1; column++) {
            pixel = row*source->rowBytes + column;
            value = magAddress[pixel];
            
            // Determine gradient direction
            float dir = 0;
            if (gxAddress[pixel]) {
                dir = atanf(gyAddress[pixel]/gxAddress[pixel]);
            } else if (gyAddress[pixel] != 0) {
                dir = 1.57;
            }
            
            // Check if maximum along gradient
            if (dir >= -0.393 && dir < 0.393) { // [-pi/8,pi/8]
                if (value < magAddress[(row-1)*source->rowBytes + column] || value < magAddress[(row+1)*source->rowBytes + column]) {
                    value = 0;
                }
            } else if (dir >= 0.393 && dir < 1.178) { // [pi/8, 3pi/8]
                if (value < magAddress[(row-1)*source->rowBytes + (column+1)] || value < magAddress[(row+1)*source->rowBytes + (column-1)]) {
                    value = 0;
                }
            } else if (dir >= -1.178 && dir < -0.393) { // [-3pi/8,-pi/8]
                if (value < magAddress[(row-1)*source->rowBytes + (column-1)] || value < magAddress[(row+1)*source->rowBytes + (column+1)]) {
                    value = 0;
                }
            } else {
                if (value < magAddress[pixel+1] || value < magAddress[pixel-1]) {
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
    free(gxAddress);
    free(gyAddress);
    free(magAddress);
    
    // Hysteresis
    // TODO: handle border here as well
//    for (int row = 2; row < source.height-2; row++) {
//        for (int column = 2; column < source.width-2; column++) {
//            pixel = row*source.rowBytes + column;
//            value = destAddress[pixel];
//            if (value == weakValue) {
//                if (destAddress[pixel-1] == strongValue || destAddress[(row-1)*source.rowBytes + column] == strongValue
//                    || destAddress[(row-1)*source.rowBytes + (column-1)] == strongValue) {
//                    value = strongValue;
//                } else {
//                    value = 0;
//                }
//             }
//            destAddress[pixel] = value;
//        }
//    }
}




- (BOOL) setupVideoInput: (CMFormatDescriptionRef) formatDescription {
    
    CMVideoDimensions videoDimensions = CMVideoFormatDescriptionGetDimensions(formatDescription);
    float bitsPerPixel;
    int numPixels = videoDimensions.width * videoDimensions.height;
    int bitsPerSecond;
    
    if (numPixels < (640*480)) {
        bitsPerPixel = 4.05;
    } else {
        bitsPerPixel = 11.4;
    }
    
    bitsPerSecond = numPixels * bitsPerPixel;
    
    NSDictionary *outputSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                    AVVideoCodecH264, AVVideoCodecKey,
                                    [NSNumber numberWithInteger:videoDimensions.width], AVVideoWidthKey,
                                    [NSNumber numberWithInteger:videoDimensions.height], AVVideoHeightKey,
                                    [NSDictionary dictionaryWithObjectsAndKeys:
                                     [NSNumber numberWithInteger:bitsPerSecond], AVVideoAverageBitRateKey,
                                     [NSNumber numberWithInteger:30], AVVideoMaxKeyFrameIntervalKey, nil ],
                                    AVVideoCompressionPropertiesKey, nil];
    
    self.assetWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:outputSettings];
    
    CGAffineTransform trans;
    
    UIDeviceOrientation deviceOrientation = [UIDevice currentDevice].orientation;
    if (deviceOrientation == UIInterfaceOrientationPortraitUpsideDown){
        trans = CGAffineTransformMakeRotation(M_PI * 0.5);
    }
    else if (deviceOrientation == UIInterfaceOrientationPortrait){
        trans = CGAffineTransformMakeRotation(M_PI * -0.5);
    }
    else if (deviceOrientation == UIInterfaceOrientationLandscapeLeft){
        trans = CGAffineTransformMakeRotation(0);
    }
    else {
        trans = CGAffineTransformMakeRotation(M_PI);
    }
    
    self.assetWriterInput.transform = trans;
    self.assetWriterInputAdaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:self.assetWriterInput sourcePixelBufferAttributes:[NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithInt:kCVPixelFormatType_OneComponent8],kCVPixelBufferPixelFormatTypeKey, nil]];
    
    if ([self.assetWriter canAddInput:self.assetWriterInput]) {
//        NSLog(@"Adding input to asset writer");
        [self.assetWriter addInput:self.assetWriterInput];
        return YES;
    } else {
        NSLog(@"Could not add input to asset writer");
        return NO;
    }
}

#pragma mark - AVCaptureFileOutputRecordingDelegateMethods

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error {
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end