//
//  ViewController.m
//  iOS6 Parallax Demo
//
//  Created by Łukasz Przytuła on 06.09.2013.
//  Copyright (c) 2013 Mildware. All rights reserved.
//

#import "ViewController.h"
#import "UIView+MWParallax.h"

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UIImageView *background;
@property (weak, nonatomic) IBOutlet UILabel *label1;
@property (weak, nonatomic) IBOutlet UILabel *label2;
@property (weak, nonatomic) IBOutlet UILabel *label3;
@property (weak, nonatomic) IBOutlet UILabel *label4;

@end

@implementation ViewController

- (void)viewDidLoad
{
  [super viewDidLoad];
  self.background.iOS6ParallaxIntensity = -10;
  self.label1.iOS6ParallaxIntensity = 10;
  self.label2.iOS6ParallaxIntensity = 20;
  self.label3.iOS6ParallaxIntensity = 30;
  self.label4.iOS6ParallaxIntensity = 40;
}

- (void)dealloc
{
  self.label1.iOS6ParallaxIntensity = 0;
  self.label2.iOS6ParallaxIntensity = 0;
  self.label3.iOS6ParallaxIntensity = 0;
  self.label4.iOS6ParallaxIntensity = 0;
}

@end
