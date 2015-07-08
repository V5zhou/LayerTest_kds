//
//  RootViewController.m
//  LayerTest_kds
//
//  Created by zmz on 15/5/7.
//  Copyright (c) 2015年 zmz. All rights reserved.
//

#import "RootViewController.h"
#import "FirstViewController.h"
#import "SecondContentsViewController.h"
#import "ThirdViewController.h"

@interface RootViewController () <UITableViewDataSource, UITableViewDelegate> {
    NSArray *Array;
}

@end

@implementation RootViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    UITableView *tab = [[UITableView alloc] initWithFrame:CGRectMake(0, 64, SCREENWIDTH, SCREENHEIGHT - 64) style:UITableViewStylePlain];
    tab.delegate = self;
    tab.dataSource = self;
    [self.view addSubview:tab];
    
    Array = @[@"遮罩",@"动态绘图",@"小妞图片圆角"];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (indexPath.row) {
        case 0:
        {
            [self.navigationController pushViewController:[[SecondContentsViewController alloc] init] animated:YES];
        }
            break;
            
        case 1:
        {
            [self.navigationController pushViewController:[[FirstViewController alloc] init] animated:YES];
        }
            break;
            
        case 2:
        {
            [self.navigationController pushViewController:[[ThirdViewController alloc] init] animated:YES];
        }
            break;
            
        default:
            break;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return Array.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"layertest"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"layertest"];
    }
    cell.textLabel.text = Array[indexPath.row];
    return cell;
}

@end
