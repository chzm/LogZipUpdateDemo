//
//  ViewController.m
//  ZMLogZipUpdateDemo
//
//  Created by chenzm on 2018/10/11.
//  Copyright © 2018年 chenzm. All rights reserved.
//

#import "ViewController.h"
#import "ZMLogZipOssHeader.h"

@interface ViewController ()

///显示日志
@property(nonatomic,strong)ZMLogView *logView;


@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self testShowLocalLog];
    
    [self testUpdateLocalFile];
    [self testUpdateLocalZipFile];
    [self testCalcuUpdateFile];
    
    [self testUpdateTodayBeforeADayFile];
}

///写入数据到本地文件并显示
-(void)testShowLocalLog{
    //写入数据到本地文件
    kLocalLog(@"错误信息(文件类/方法)",@"具体信息啊啊啊啊啊啊");
    //获取日志信息并显示
    NSString *str = [[LogManager sharedInstance] readFile:@"2018-10-11"];
    NSLog(@"%@",str);
    //渲染
    [self.logView logInfo:str];
}

///1、直接上传文件
-(void)testUpdateLocalFile{
    [[ZMAliOSSManager shareManager] zm_configClient];
    
    //获取文件路径
    NSString *path = [NSString stringWithFormat:@"%@%@%@",NSHomeDirectory(),kCacheLogFilePath,@"2018-10-11"];
    //上传后文件的名称
    NSString *upFileNameStr = @"test[2018-10-11]";
    
    [[ZMAliOSSManager shareManager] zm_putResourceWithLocalFilePath:path fileName:upFileNameStr response:^(BOOL isSuccess, NSString *resultUrl) {
        if (isSuccess == YES) {
            NSLog(@"上传文件成功");
        }
    }];
}

///2、压缩打包后上传文件
-(void)testUpdateLocalZipFile{
    [[ZMAliOSSManager shareManager] zm_configClient];
    
    //    NSDictionary *dic = @{@"type":@"0"};
    //    NSDictionary *dic1 = @{@"type":@"1",@"dates":@[@"2018-10-11",@"2018-10-09"]};
    NSDictionary *dic2 = @{@"type":@"2"};
    //上传后文件的名称
    NSString *upFileNameStr = @"ZMDemo压缩包测试";
    
    [[LogManager sharedInstance] zm_uploadZipFile:dic2 upFileName:upFileNameStr];
}


///3、根据上传文件的大小上传文件
-(void)testCalcuUpdateFile{
    [[ZMAliOSSManager shareManager] zm_configClient];
    
    //获取文件路径
    NSString *path = [NSString stringWithFormat:@"%@%@%@",NSHomeDirectory(),kCacheLogFilePath,@"2018-10-11"];
    CGFloat file_size = [[LogManager sharedInstance] zm_calculatorFileSizeAtPath:path];
    if (file_size > 1.0) {//如果文件大于1MB，则打包上传
        NSDictionary *dic1 = @{@"type":@"1",@"dates":@[@"2018-10-11"]};
        //上传后文件的名称
        NSString *upFileNameStr = @"ZMDemo压缩包测试";
        [[LogManager sharedInstance] zm_uploadZipFile:dic1 upFileName:upFileNameStr];
    }else{
        //上传后文件的名称
        NSString *upFileNameStr = @"test[2018-10-11]";
        [[ZMAliOSSManager shareManager] zm_putResourceWithLocalFilePath:path fileName:upFileNameStr response:^(BOOL isSuccess, NSString *resultUrl) {
            if (isSuccess == YES) {
                NSLog(@"上传文件成功");
            }
        }];
    }
}

///4、上传隔天上一个的日志文件
-(void)testUpdateTodayBeforeADayFile{
    [[ZMAliOSSManager shareManager] zm_configClient];
    NSString *fileName = [[LogManager sharedInstance] zm_getUpdateLogFileName];
    [[LogManager sharedInstance] zm_updateFileWithUpName:fileName];
}


#pragma mark - lazyload

-(ZMLogView *)logView{
    if (!_logView) {
        _logView = [ZMLogView initLogView];
        [self.view addSubview:_logView];
    }
    return _logView;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end

