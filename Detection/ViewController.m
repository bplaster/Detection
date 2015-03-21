//
//  ViewController.m
//  Detection
//
//  Created by Brandon Plaster on 3/6/15.
//  Copyright (c) 2015 BrandonPlaster. All rights reserved.
//


#import "ViewController.h"
#import "ImageViewController.h"

@interface ViewController () <UINavigationControllerDelegate, UIImagePickerControllerDelegate>

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
}

- (IBAction)galleryButtonPressed:(id)sender {
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
    ImageViewController *imageViewController = [[ImageViewController alloc] initWithImage:image];
    
    [self presentViewController:imageViewController animated:YES completion:nil];
    
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end