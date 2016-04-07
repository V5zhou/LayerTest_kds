//
//  ThirdViewController.m
//  LayerTest_kds
//
//  Created by zmz on 15/5/15.
//  Copyright (c) 2015年 zmz. All rights reserved.
//

#import "ThirdViewController.h"

@interface ThirdViewController () {
    CALayer *layer1;
    CALayer *layer2;
    CAShapeLayer *shapeLayer;
}

@end

@implementation ThirdViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    layer1 = [[CALayer alloc] init];
    layer1.bounds = CGRectMake(0, 64, SCREENWIDTH, SCREENHEIGHT - 64);
    layer1.position = CGPointMake(SCREENWIDTH/2, SCREENHEIGHT/2 + 32);
    layer1.delegate = self;
    
    layer2 = [[CALayer alloc] init];
    layer2.bounds = CGRectMake(0, 64, SCREENWIDTH, SCREENHEIGHT - 64);
    layer2.position = CGPointMake(SCREENWIDTH/2, SCREENHEIGHT/2 + 32);
    layer2.delegate = self;
    
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathAddArc(path, NULL, SCREENWIDTH/4, SCREENWIDTH/4, SCREENWIDTH/4, 0, M_PI*2, YES);
    
    shapeLayer = [[CAShapeLayer alloc] init];
    [shapeLayer setBounds:CGRectMake(0, 0, SCREENWIDTH/2, SCREENWIDTH/2)];
    [shapeLayer setPosition:CGPointMake(SCREENWIDTH/4, SCREENWIDTH/4)];
    [shapeLayer setPath:path];
    shapeLayer.shadowOffset = CGSizeMake(8, 8);
    shapeLayer.shadowRadius = 10;
    shapeLayer.shadowOpacity = 0.7;
    
    [layer2 setMask:shapeLayer];
    
    [self.view.layer addSublayer:layer1];
    [self.view.layer addSublayer:layer2];
    [layer1 setNeedsDisplay];
    [layer2 setNeedsDisplay];
}

- (void)drawLayer:(CALayer *)layer inContext:(CGContextRef)ctx {
    UIGraphicsPushContext(ctx);
    if (layer == layer1) {
        layer1.backgroundColor = [[UIColor whiteColor] CGColor];
    }
    else if (layer == layer2) {
        UIImage *image = [UIImage imageNamed:@"3.jpg"];
        [image drawInRect:layer.bounds];
    }
    UIGraphicsPopContext();
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    CGPoint point = [[touches anyObject] locationInView:self.view];
    [shapeLayer setPosition:point];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    CGPoint point = [[touches anyObject] locationInView:self.view];
    [shapeLayer setPosition:point];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    layer2.delegate = nil;
    layer1.delegate = nil;
}

@end
