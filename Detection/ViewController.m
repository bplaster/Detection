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

@property (nonatomic, strong) AVCaptureSession *captureSession;
//@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic, strong) AVCaptureMovieFileOutput *movieFileOutput;
@property (nonatomic, assign) VFRecordingState recordingState;
@property (strong, nonatomic) IBOutlet UIButton *recordButton;
@property (nonatomic, strong) AVCaptureVideoDataOutput *videoOutput;
@property (strong, nonatomic) IBOutlet UISlider *thresholdSlider;
@property (nonatomic, assign) BOOL edgesEnabled;

@property (nonatomic, strong) CALayer *previewLayer;
@property (nonatomic, strong) NSURL *fileURL;
@property (nonatomic, assign) BOOL assetWriterVideoInputReady;
@property (nonatomic, strong) AVAssetWriter *assetWriter;
@property (nonatomic, strong) dispatch_queue_t assetWritingQueue;
@property (nonatomic, strong) AVAssetWriterInput *assetWriterInput;

// Kernels
@property (nonatomic, assign) int8_t* kernel;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    // Setup kernels
    //self.kernel = &((int8_t){-2, -2, 0, -2, 6, 0, 0, 0, 0});
    self.edgesEnabled = NO;
    
    // Setup layer for preview
    self.previewLayer = [CALayer layer];
    [self.previewLayer setFrame:self.view.bounds];
    [self.view.layer insertSublayer:self.previewLayer atIndex:0];
    
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

    // Start
    [self.captureSession startRunning];
}

-(void) createNewWriter{
    self.assetWriter = [[AVAssetWriter alloc] initWithURL:self.fileURL fileType:AVFileTypeQuickTimeMovie error:nil];
    self.assetWriterVideoInputReady = NO;
}

-(void) orientationChanged
{
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

    UIDeviceOrientation deviceOrientation = [UIDevice currentDevice].orientation;
    if (deviceOrientation == UIInterfaceOrientationPortraitUpsideDown)
        [videoConnection setVideoOrientation:AVCaptureVideoOrientationPortraitUpsideDown];
    
    else if (deviceOrientation == UIInterfaceOrientationPortrait)
        [videoConnection setVideoOrientation:AVCaptureVideoOrientationPortrait];
    
    else if (deviceOrientation == UIInterfaceOrientationLandscapeLeft)
        [videoConnection setVideoOrientation:AVCaptureVideoOrientationLandscapeLeft];
    
    else
        [videoConnection setVideoOrientation:AVCaptureVideoOrientationLandscapeRight];
}

- (IBAction)toggleEdgeChanged:(id)sender {
    
    self.edgesEnabled = [((UISwitch *)sender) isOn];
}

- (IBAction)recordButtonPressed:(id)sender {
    if (self.recordingState == VFRecordingStateRecording) {
        [self.recordButton setTitle:@"Record" forState:UIControlStateNormal];
        
        [self.movieFileOutput stopRecording];
        [self.assetWriter finishWritingWithCompletionHandler:^{
            [self createNewWriter];
        }];
        
        self.recordingState = VFRecordingStateFinished;
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
    NSLog(@"play");
    
    MPMoviePlayerViewController *moviePlayerVC = [[MPMoviePlayerViewController alloc] initWithContentURL:self.fileURL];
    [self presentMoviePlayerViewControllerAnimated:moviePlayerVC];
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegateMethods

- (void) processPixelBuffer: (CVImageBufferRef) pixelBuffer {
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    
//    size_t bufferWidth = CVPixelBufferGetWidth(pixelBuffer);
//    size_t bufferHeight = CVPixelBufferGetHeight(pixelBuffer);
//    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer);
//    unsigned char *baseAddress = (unsigned char *)CVPixelBufferGetBaseAddress(pixelBuffer);

    size_t width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0);
    size_t height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
    unsigned char *baseAddress = (unsigned char *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
    unsigned char *destAddress = malloc(bytesPerRow*height);
    int bitsPerComponent = 8;
    
    vImage_Buffer src = { baseAddress, height, width, bytesPerRow };
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
    CGContextRef context;

    if (self.edgesEnabled) {
        vImage_Buffer dest = {destAddress, height, width, bytesPerRow };
        [self cannyDetector:src toDestination:dest withMinVal:75 andMaxVal:100];
        context = CGBitmapContextCreate(destAddress, width, height, bitsPerComponent, bytesPerRow, colorSpace, kCGImageAlphaNone);
    } else {
        context = CGBitmapContextCreate(baseAddress, width, height, bitsPerComponent, bytesPerRow, colorSpace, kCGImageAlphaNone);
    }
    
    CGImageRef imageRef = CGBitmapContextCreateImage(context);
    
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    free(destAddress);
    
    dispatch_sync(dispatch_get_main_queue(), ^{
        [self.view.layer setContents: (__bridge id)imageRef];
        CGImageRelease(imageRef);
    });
}

// Canny edge detector
// Notes:   Assumes you've already allocated memory for destination
//          Assumes 1 byte per pixel
- (void) cannyDetector: (vImage_Buffer)source toDestination: (vImage_Buffer)destination withMinVal:(int)minVal andMaxVal:(int)maxVal {
    
    size_t arraySize = source.rowBytes*source.height;
    
    // Gaussian
    const int16_t gaussKernel[25] = {2,4,5,4,2,4,9,12,9,4,5,12,15,12,5,4,9,12,9,4,2,4,5,4,2};
    vImageConvolve_Planar8(&source, &destination, NULL, 0, 0, gaussKernel, 5, 5, 115, 0, kvImageEdgeExtend);
    
    // Partial derivative arrays
    signed char *gxAddress = malloc(arraySize);
    signed char *gyAddress = malloc(arraySize);
    vImage_Buffer gx = {gxAddress, source.height, source.width, source.rowBytes};
    vImage_Buffer gy = {gyAddress, source.height, source.width, source.rowBytes};
    
    // Sobel
    const int16_t vKernel[9] = {-1, 0, 1, -2, 0, 2, -1, 0, 1};
    const int16_t hKernel[9] = {1, 2, 1, 0, 0, 0, -1, -2, -1};
    vImageConvolve_Planar8(&destination, &gx, NULL, 0, 0, hKernel, 3, 3, 1, 0, kvImageEdgeExtend);
    vImageConvolve_Planar8(&destination, &gy, NULL, 0, 0, vKernel, 3, 3, 1, 0, kvImageEdgeExtend);
    
    // Direction and Magnitude
    unsigned char *magAddress = malloc(arraySize);
//    float *dirAddress = malloc(arraySize*sizeof(float));
    unsigned long pixel = 0;
    for (int row = 0; row < source.height; row++) {
        for (int column = 0; column < source.width; column++) {
            pixel = row*source.rowBytes + column;
            magAddress[pixel] = sqrtf(powf(gxAddress[pixel], 2)+powf(gyAddress[pixel], 2)); // Could approximate by abs(gx) + abs(gy)
//            if (gxAddress[pixel]) {
//                dirAddress[pixel] = atanf(gyAddress[pixel]/gxAddress[pixel]);
//            } else {
//                dirAddress[pixel] = 0;
//            }
        }
    }

    // Non-maximal suppression && Double threshold
    // TODO: need to handle border
    int value = 0;
    for (int row = 1; row < source.height-1; row++) {
        for (int column = 1; column < source.width-1; column++) {
            pixel = row*source.rowBytes + column;
            value = 0;
            
            float dir = 0;
            if (gxAddress[pixel]) {
                dir = atanf(gyAddress[pixel]/gxAddress[pixel]);
            } else if (gyAddress[pixel] != 0) {
                dir = 1.57;
            }
            
            // Check if maximum along gradient
            if (dir >= -0.393 && dir < 0.393) { // [-pi/8,pi/8] E-W
                if (magAddress[pixel] > magAddress[pixel+1] && magAddress[pixel] > magAddress[pixel-1]) {
                    value = magAddress[pixel];
                }
            } else if (dir >= 0.393 && dir < 1.178) { // [pi/8, 3pi/8] NE-SW
                if (magAddress[pixel] > magAddress[(row-1)*source.rowBytes + (column-1)] && magAddress[pixel] > magAddress[(row+1)*source.rowBytes + (column+1)]) {
                    value = magAddress[pixel];
                }
            } else if (dir >= -1.178 && dir < -0.393) { // NW-SE
                if (magAddress[pixel] > magAddress[(row-1)*source.rowBytes + (column+1)] && magAddress[pixel] > magAddress[(row+1)*source.rowBytes + (column-1)]) {
                    value = magAddress[pixel];
                }
            } else { // N-S
                if (magAddress[pixel] > magAddress[(row-1)*source.rowBytes + column] && magAddress[pixel] > magAddress[(row+1)*source.rowBytes + column]) {
                    value = magAddress[pixel];
                }
            }
//            // Check if maximum along gradient
//            if (dirAddress[pixel] >= -0.393 && dirAddress[pixel] < 0.393) { // [-pi/8,pi/8] E-W
//                if (magAddress[pixel] > magAddress[pixel+1] && magAddress[pixel] > magAddress[pixel-1]) {
//                    value = magAddress[pixel];
//                }
//            } else if (dirAddress[pixel] >= 0.393 && dirAddress[pixel] < 1.178) { // [pi/8, 3pi/8] NE-SW
//                if (magAddress[pixel] > magAddress[(row-1)*source.rowBytes + (column-1)] && magAddress[pixel] > magAddress[(row+1)*source.rowBytes + (column+1)]) {
//                    value = magAddress[pixel];
//                }
//            } else if (dirAddress[pixel] >= -1.178 && dirAddress[pixel] < -0.393) { // NW-SE
//                if (magAddress[pixel] > magAddress[(row-1)*source.rowBytes + (column+1)] && magAddress[pixel] > magAddress[(row+1)*source.rowBytes + (column-1)]) {
//                    value = magAddress[pixel];
//                }
//            } else { // N-S
//                if (magAddress[pixel] > magAddress[(row-1)*source.rowBytes + column] && magAddress[pixel] > magAddress[(row+1)*source.rowBytes + column]) {
//                    value = magAddress[pixel];
//                }
//            }
            
            // Double Threshold
            if (value > maxVal) {
                value = 255;
            } else if (value > minVal) {
                value = 100;
            } else {
                value = 0;
            }
            ((unsigned char *)destination.data)[row*destination.rowBytes + column] = value;
        }
    }
    free(gxAddress);
    free(gyAddress);
    
    free(magAddress);
//    free(dirAddress);

}

- (void) captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    
    CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    [self processPixelBuffer:pixelBuffer];

    
    if (!self.assetWriterVideoInputReady) {
        self.assetWriterVideoInputReady = [self setupVideoInput:CMSampleBufferGetFormatDescription(sampleBuffer)];
    }
    
    switch (self.recordingState) {
        case VFRecordingStateFinished: {
            break;
        }
        case VFRecordingStateRecording: {
            if (self.assetWriter) {
                CFRetain(sampleBuffer);
                dispatch_async(self.assetWritingQueue, ^{
                    if (self.assetWriter.status == AVAssetWriterStatusUnknown) {
                        if ([self.assetWriter startWriting]) {
                            CMTime startTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
                            [self.assetWriter startSessionAtSourceTime:startTime];
                        }
                    }
                    if (self.assetWriter.status == AVAssetWriterStatusWriting) {
                        if (self.assetWriterInput.isReadyForMoreMediaData) {
                            [self.assetWriterInput appendSampleBuffer:sampleBuffer];
                        }
                    }
                    CFRelease(sampleBuffer);
                });
            }
            break;
        }
        default:
            break;
    }
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
    
    if ([self.assetWriter canAddInput:self.assetWriterInput]) {
        NSLog(@"Adding input to asset writer");
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