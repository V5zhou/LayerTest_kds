//
//  FirstViewController.m
//  LayerTest_kds
//
//  Created by zmz on 15/5/7.
//  Copyright (c) 2015年 zmz. All rights reserved.
//

#import "FirstViewController.h"

@interface FirstViewController ()

@end

@implementation FirstViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.layer.backgroundColor = [[UIColor whiteColor] CGColor];
    for (NSInteger i = 0; i < 8; i ++) {
        CGRect tempRect = CGRectMake(i%2*(SCREENWIDTH/2.0) + 10, (i/2)*((SCREENHEIGHT-60)/4.0) + 70, SCREENWIDTH/2.0 - 20, (SCREENHEIGHT-60)/4.0 - 20);
        CGPoint center = CGPointMake(tempRect.origin.x + tempRect.size.width/2, tempRect.origin.y + tempRect.size.height/2);
        UIBezierPath *path;
        switch (i) {
            case 0:
                path = [self drawCircle:tempRect.size.height/2 - 5 frame:tempRect center:center];
                break;
                
            case 1:
                path = [self draw3CurveLineInRect:tempRect];
                break;
                
            case 2:
                path = [self drawOvalInRect:tempRect];
                break;
                
            case 3:
                path = [self drawRect:tempRect cornerRadius:6];
                break;
                
            case 4:
                path = [self drawLineInRect:tempRect];
                break;
                
            case 5:
                path = [self draw2CurveLineInRect:tempRect];
                break;
                
            case 6:
                break;
                
            case 7:
                break;
                
            default:
                break;
        }
//----------------->下面是三种取出图像方法。
        if (i < 6) {       //确定path后，通过layer去展示，线宽，颜色，填充等只能由layer决定
            CAShapeLayer *shape = [[CAShapeLayer alloc] init];
            [shape setBounds:tempRect];
            [shape setPosition:center];
            shape.fillColor = [[UIColor whiteColor] CGColor];
            shape.strokeColor = [[UIColor greenColor] CGColor];
            shape.lineWidth = 1;
            shape.shouldRasterize = YES;
            shape.path = path.CGPath;
            
            CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:NSStringFromSelector(@selector(strokeEnd))];
            animation.fromValue = @0;
            animation.toValue = @1;
            animation.duration = 5;
            [shape addAnimation:animation forKey:NSStringFromSelector(@selector(strokeEnd))];
            
            [self.view.layer addSublayer:shape];
        }
        else {            //联系上下文，取出image刷到layer
            CALayer *layer = [[CALayer alloc] init];
            [layer setBounds:tempRect];
            [layer setPosition:center];
            if (i == 6) {
                [layer setContents:(id)[[self getSJImage:tempRect] CGImage]];
            }
            else if (i == 7) {
                [layer setContents:(id)[[self drawDashLineFrame:tempRect] CGImage]];
            }
            
            [self.view.layer addSublayer:layer];
        }
    }
}

//画圆
- (UIBezierPath *)drawCircle:(CGFloat)radius frame:(CGRect)frame center:(CGPoint)center{
    UIBezierPath *path = [UIBezierPath bezierPathWithArcCenter:center radius:radius startAngle:0 endAngle:M_PI*2 clockwise:YES];
    return path;
}

//画虚线

- (UIImage *)drawDashLineFrame:(CGRect)frame {
    UIGraphicsBeginImageContext(frame.size);
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:CGPointZero];
    [path addLineToPoint:CGPointMake(frame.size.width, frame.size.height)];
    CGFloat dash[2] = {10,10};
    [path setLineDash:dash count:2 phase:0];
    [path setLineWidth:4];
    [[UIColor redColor] setStroke];
    [path stroke];
    [path fill];
    [path closePath];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    return image;
}

//画椭圆
- (UIBezierPath *)drawOvalInRect:(CGRect)frame {
    UIBezierPath *path = [UIBezierPath bezierPathWithOvalInRect:frame];
    return path;
}

//画圆角
- (UIBezierPath *)drawRect:(CGRect)frame cornerRadius:(CGFloat)radius {
//画方形
//    UIBezierPath *path = [UIBezierPath bezierPathWithRect:frame];
    
//    画指定圆角
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:frame byRoundingCorners:UIRectCornerTopRight|UIRectCornerBottomRight cornerRadii:CGSizeMake(10, 10)];
//画圆角
//    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:frame cornerRadius:radius];
    return path;
}

//画线

- (UIBezierPath *)drawLineInRect:(CGRect)frame {
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:frame.origin];
    [path addLineToPoint:CGPointMake(frame.origin.x+frame.size.width, frame.origin.y+frame.size.height)];
    return path;
}

//画二次方曲线
- (UIBezierPath *)draw2CurveLineInRect:(CGRect)frame {
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:frame.origin];
    [path addQuadCurveToPoint:CGPointMake(frame.origin.x + frame.size.width, frame.origin.y) controlPoint:CGPointMake(frame.origin.x + frame.size.width/2, frame.origin.y + frame.size.height * 2)];
    return path;
}

//画三次方曲线
- (UIBezierPath *)draw3CurveLineInRect:(CGRect)frame {
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:frame.origin];
    [path addCurveToPoint:CGPointMake(frame.origin.x + frame.size.width, frame.origin.y + frame.size.height) controlPoint1:CGPointMake(frame.origin.x, frame.origin.y + frame.size.height) controlPoint2:CGPointMake(frame.origin.x + frame.size.width, frame.origin.y + frame.size.height/2)];
    return path;
}

//联系上下文，取出画的三角形
- (UIImage *)getSJImage:(CGRect)bounce{
    UIGraphicsBeginImageContext(bounce.size);
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:CGPointMake(10, 10)];
    [path addLineToPoint:CGPointMake(120, 10)];
    [path addLineToPoint:CGPointMake(50, 70)];
    [path addLineToPoint:CGPointMake(10, 10)];
    [path setLineWidth:4];
    [[UIColor redColor] setStroke];
    [[UIColor grayColor] setFill];
    [path stroke];
    [path fill];
    [path closePath];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    return image;
}

@end

