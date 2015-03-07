//
//  ViewController.m
//  Detection
//
//  Created by Brandon Plaster on 3/6/15.
//  Copyright (c) 2015 BrandonPlaster. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
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
@property (strong, nonatomic) IBOutlet UIImageView *previewImageView;
@property (nonatomic, strong) AVCaptureVideoDataOutput *videoOutput;

@property (nonatomic, strong) CALayer *previewLayer;
@property (nonatomic, strong) NSURL *fileURL;
@property (nonatomic, assign) BOOL assetWriterVideoInputReady;
@property (nonatomic, strong) AVAssetWriter *assetWriter;
@property (nonatomic, strong) dispatch_queue_t assetWritingQueue;
@property (nonatomic, strong) AVAssetWriterInput *assetWriterInput;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.previewLayer = [CALayer layer];
    [self.previewLayer setFrame:self.view.bounds];
//    self.previewLayer.bounds = CGRectMake(0, 0, self.view.frame.size.height, self.view.frame.size.width);
//    self.previewLayer.position = CGPointMake(self.view.frame.size.width/2., self.view.frame.size.height/2.);
//    self.previewLayer.affineTransform = CGAffineTransformMakeRotation(M_PI/2);
    [self.view.layer insertSublayer:self.previewLayer atIndex:0];
    
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
    
    //self.previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.captureSession];
    //self.previewLayer.frame = self.view.frame;
    
    //    self.movieFileOutput = [AVCaptureMovieFileOutput new];
    //    [self.captureSession addOutput:self.movieFileOutput];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(orientationChanged)
                                                 name:UIDeviceOrientationDidChangeNotification
                                               object:nil];
    
    self.videoOutput = [AVCaptureVideoDataOutput new];
    [self.videoOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInteger:kCVPixelFormatType_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
    
    dispatch_queue_t videoDataDispatchQueue = dispatch_queue_create("edu.CS2049.videoDataOutputQueue", DISPATCH_QUEUE_SERIAL);
    [self.videoOutput setSampleBufferDelegate:self queue:videoDataDispatchQueue];
    [self.captureSession addOutput:self.videoOutput];
    
    self.fileURL = [[NSURL alloc] initFileURLWithPath:[NSString pathWithComponents:@[NSTemporaryDirectory(), @"myFilename.mp4"]]];
    
    [self createNewWriter];
    self.assetWritingQueue = dispatch_queue_create("edu.CS2049.assetWritingQueue", DISPATCH_QUEUE_SERIAL);
    
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
    
    size_t bufferWidth = CVPixelBufferGetWidth(pixelBuffer);
    size_t bufferHeight = CVPixelBufferGetHeight(pixelBuffer);
    unsigned char *baseAddress = (unsigned char *)CVPixelBufferGetBaseAddress(pixelBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer);
    int bytesPerPixel = 4;
    int bitsPerComponent = 8;
    int greenValue = 0;

    for (int row = 0; row < bufferHeight; row++) {
        for (int column = 0; column < bufferWidth; column++) {
            baseAddress[row*bytesPerRow + column*bytesPerPixel + 1] = greenValue;
        }
    }

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(baseAddress, bufferWidth, bufferHeight, bitsPerComponent, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    CGImageRef imageRef = CGBitmapContextCreateImage(context);
    
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    
    dispatch_sync(dispatch_get_main_queue(), ^{
        [self.view.layer setContents: (__bridge id)imageRef];
        CGImageRelease(imageRef);
    });

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