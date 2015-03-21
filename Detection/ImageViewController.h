//
//  ImageViewController.h
//  Detection
//
//  Created by Brandon Plaster on 3/17/15.
//  Copyright (c) 2015 BrandonPlaster. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ImageViewController : UIViewController

@property (nonatomic, strong) IBOutlet UIImageView *imageView;
@property (nonatomic, strong) UIImage *image;

- (id) initWithImage: (UIImage *) image;


@end
