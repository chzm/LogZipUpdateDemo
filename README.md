# LogZipUpdateDemo
 @[TOC](目录)
### 一、简述
发现APP上传本地日志文件相当的好用，根据之前研究学习的对这一模块做了一些更具体的[优化处理](https://gitee.com/chenzm_186/ZMLogZipUpdateDemo)。从标题可以看出，实现这一功能分以下几个步骤：
1、日志记录本地文件
2、日志文件压缩[xx.zip]
3、压缩之后的文件上传
4、压缩文件删除
这里写了一个【[Demo](https://download.csdn.net/download/weixin_38633659/10715348)】，将日志记录和日志压缩放在【LogManager】文件，日志上传放在【ZMAliOSSManager】文件，日志上传OSS我只用了一个简单上传的实现，没有做鉴权处理和其他上传方式，但是相关的实现方法写集成了，希望需要的有用。当然这也不影响我对功能的实现，以下是我实现功能的几个实例：

```oc
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
    
    //写入数据到本地文件并显示
    [self testShowLocalLog];
    
    //1、直接上传文件(不压缩)
    [self testUpdateLocalFile];
    
    //2、压缩打包后上传文件
    [self testUpdateLocalZipFile];
    
    //3、根据上传文件的大小上传文件
    [self testCalcuUpdateFile];
    
    //4、上传隔天上一个的日志文件
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

```

### 二、实现步骤
是不是发现很好用，让我们来看看是怎么实现的吧：
 1、下载【[Demo](https://download.csdn.net/download/weixin_38633659/10715348)】，将【ZMTools】文件夹内的所有文件导入项目。
 2、创建【Podfile】工程，在[Podfile]文件中导入两个包：
 ```oc
 #压缩文件包
 pod 'ZipArchive', '1.4.0',:inhibit_warnings => true
 #阿里云OSS
 pod 'AliyunOSSiOS','2.10.5',:inhibit_warnings => true
 ```
 3、在需要压缩上传的文件类中引入文件【ZMLogZipOssHeader.h】，
```oc
#import "ZMLogZipOssHeader.h"
```
在需要记录文件的文件中引入文件类【LogManager.h】。
 ```oc
 //写入数据到本地文件
    kLocalLog(@"错误信息(文件类/方法)",@"具体信息啊啊啊啊啊啊");
```
 4、调用方法实现,见第一段代码。

### 三、参考链接
1、[iOS开发：日志记录及AFNetworking请求](https://blog.csdn.net/weixin_38633659/article/details/82758210)
