//
//  GradientColorViewController.m
//  LayerTest_kds
//
//  Created by zmz on 15/9/16.
//  Copyright (c) 2015年 zmz. All rights reserved.
//

#import "GradientColorViewController.h"

@interface GradientColorViewController ()

@end

@implementation GradientColorViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    //
    self.view.backgroundColor = [UIColor whiteColor];
    
    //创建CGContextRef
    UIGraphicsBeginImageContext(self.view.bounds.size);
    CGContextRef gc = UIGraphicsGetCurrentContext();
    
    UIBezierPath *path = [UIBezierPath bezierPathWithArcCenter:CGPointMake(SCREENWIDTH/2, SCREENHEIGHT/2) radius:100 startAngle:-M_PI endAngle:M_PI clockwise:YES];
    
    //绘制渐变
    [self drawLinearGradient:gc path:path.CGPath startColor:[UIColor greenColor].CGColor endColor:[UIColor redColor].CGColor];
    
    
    //从Context中获取图像，并显示在界面上
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    UIImageView *imgView = [[UIImageView alloc] initWithImage:img];
    [self.view addSubview:imgView];
}

/**
 * 渐变色，分为线性和径向渐变
 */
- (void)drawLinearGradient:(CGContextRef)context
                      path:(CGPathRef)path
                startColor:(CGColorRef)startColor
                  endColor:(CGColorRef)endColor
{
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGFloat locations[] = { 0.0, 1.0 };
    
    NSArray *colors = @[(__bridge id) startColor, (__bridge id) endColor];
    
    CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef) colors, locations);
    
    CGRect pathRect = CGPathGetBoundingBox(path);
    
    CGContextSaveGState(context);
    CGContextAddPath(context, path);
    CGContextClip(context);
#if 0
    //具体方向可根据需求修改
    CGPoint startPoint = CGPointMake(CGRectGetMidX(pathRect), CGRectGetMinY(pathRect));
    CGPoint endPoint = CGPointMake(CGRectGetMidX(pathRect), CGRectGetMaxY(pathRect));
    CGContextDrawLinearGradient(context, gradient, startPoint, endPoint, 0);
#else
    CGPoint startPoint = CGPointMake(CGRectGetMinX(pathRect), CGRectGetMinY(pathRect));
    CGPoint endPoint = CGPointMake(CGRectGetMidX(pathRect), CGRectGetMidY(pathRect));
    CGContextDrawRadialGradient(context, gradient, startPoint, 0, endPoint, CGRectGetWidth(pathRect), kCGGradientDrawsAfterEndLocation);
#endif
    CGContextRestoreGState(context);
    
    CGGradientRelease(gradient);
    CGColorSpaceRelease(colorSpace);
}

@end
