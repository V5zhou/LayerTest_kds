//
//  SecondContentsViewController.m
//  LayerTest_kds
//
//  Created by zmz on 15/5/13.
//  Copyright (c) 2015年 zmz. All rights reserved.
//

#import "SecondContentsViewController.h"

@interface SecondContentsViewController () {
    CAShapeLayer *shapeLayer;
    CALayer *layer1;
    CALayer *layer2;
}

@end

@implementation SecondContentsViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    layer1 = [[CALayer alloc] init];
    [layer1 setBounds:self.view.bounds];
    [layer1 setPosition:self.view.center];
    layer1.delegate = self;
    [layer1 setNeedsDisplay];
    [self.view.layer addSublayer:layer1];
    
    layer2 = [[CALayer alloc] init];
    [layer2 setBounds:self.view.layer.bounds];
    [layer2 setPosition:self.view.layer.position];
    layer2.delegate = self;
    [layer2 setNeedsDisplay];
    
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathMoveToPoint(path, NULL, 0, 100);
    CGPathAddLineToPoint(path, NULL, 200, 0);
    CGPathAddLineToPoint(path, NULL, 200, 200);
    CGPathAddLineToPoint(path, NULL, 0, 100);
    
    shapeLayer = [[CAShapeLayer alloc] init];
    [shapeLayer setBounds:CGRectMake(0, 0, 200, 200)];
    [shapeLayer setFillColor:[[UIColor cyanColor] CGColor]];
    [shapeLayer setFillRule:kCAFillRuleEvenOdd];
    [shapeLayer setPath:path];
    [shapeLayer setPosition:CGPointMake(200, 200)];
    
    [shapeLayer setStrokeColor:[[UIColor greenColor] CGColor]];
    [shapeLayer setLineWidth:15];
    [shapeLayer setLineJoin:kCALineJoinRound];
    
    [shapeLayer setLineDashPattern:[NSArray arrayWithObjects:[NSNumber numberWithInt:50], [NSNumber numberWithInt:20], nil]];
    
    [layer2 setMask:shapeLayer];
    
    [self.view.layer addSublayer:layer2];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    CGPoint point = [[touches anyObject] locationInView:self.view];
    [shapeLayer setPosition:point];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    CGPoint point = [[touches anyObject] locationInView:self.view];
    [shapeLayer setPosition:point];
}

- (void)drawLayer:(CALayer *)layer inContext:(CGContextRef)ctx {
    
    UIGraphicsPushContext(ctx);
    if (layer == layer1) {
        UIImage *img = [UIImage imageNamed:@"2.png"];
        [img drawInRect:layer1.bounds];
    }
    else if (layer == layer2) {
        UIImage *img2 = [UIImage imageNamed:@"1.jpg"];
        [img2 drawInRect:layer2.bounds];
    }
    
    NSString *string = @"你好1234567890";
    NSDictionary *dic = @{NSFontAttributeName:[UIFont systemFontOfSize:14],
                          NSForegroundColorAttributeName:(layer == layer1) ? [UIColor redColor] : [UIColor greenColor]};
    
    [string drawAtPoint:layer.position withAttributes:dic];
    UIGraphicsPopContext();
    
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    layer1.delegate = nil;
    layer2.delegate = nil;
}

@end
