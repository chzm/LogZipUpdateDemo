//
//  ZMLogZipOssHeader.h
//  LogZipUpdateDemo
//
//  Created by chenzm on 2018/10/12.
//  Copyright © 2018年 chenzm. All rights reserved.
//

/**
 1、将【ZMTools】文件夹内的所有文件导入项目
 
 2、创建【Podfile】工程，在[Podfile]文件中导入两个包：
 -----------------
 #压缩文件包
 pod 'ZipArchive', '1.4.0',:inhibit_warnings => true
 #阿里云OSS
 pod 'AliyunOSSiOS','2.10.5',:inhibit_warnings => true
 -----------------
 3、在需要压缩上传的文件类中引入文件【ZMLogZipOssHeader.h】，在需要记录文件的文件中引入文件类【LogManager.h】
 4、调用方法实现,见【ViewController.m】
 
 */

#ifndef ZMLogZipOssHeader_h
#define ZMLogZipOssHeader_h

//tools
#import "LogManager.h"
#import "ZMAliOSSManager.h"

//views
#import "ZMLogView.h"


#endif /* ZMLogZipOssHeader_h */
