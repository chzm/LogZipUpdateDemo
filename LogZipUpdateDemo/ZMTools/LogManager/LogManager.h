//
//  LogManager.h
//  Demo
//
//  Created by chenzm on 2018/9/7.
//  Copyright © 2018年 chenzm. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

//// 记录本地日志
#define kLocalLog(module,...) {\
[[LogManager sharedInstance] logInfo:module logStr:__VA_ARGS__,nil];\
}

// 本地日志文件格式
#define kLogFileNameFormat @"yyyy-MM-dd"

// 日志保留最大天数
static const int kLogMaxSaveDay = 7;

// 日志文件 保存目录
static const NSString* kCacheLogFilePath = @"/Documents/ZMLog/";

// 日志文件 获取目录
static const NSString* kGetLogFilePath = @"Documents/ZMLog";

// 日志压缩包文件名
static NSString* kZipFileName = @"ZMLog.zip";


@interface LogManager : NSObject

/**
 *  获取单例实例
 *
 *  @return 单例实例
 */
+ (instancetype) sharedInstance;

#pragma mark - Method

/**
 *  写入日志
 *
 *  @param module 模块名称
 *  @param logStr 日志信息,动态参数
 */
- (void)logInfo:(NSString*)module logStr:(NSString*)logStr, ...;

/**
 移除文件
 @param cacheNum 还需要保存的数量
 */
-(void)deleteFileWithCacheNum:(NSInteger)cacheNum;

///获取本地文件的总数量
-(NSInteger)getLocalFileTotalNum;

///获取最早的一个文件名称
-(NSString *)getOldestFileName;

///获取最近一个文件名称
-(NSString *)getLastFileName;

/**
 读取文件信息
 @param filePath 文件路径
 */
- (NSString *)readFile:(NSString *)filePath;

/**
 获取对应日期做为文件名
 @param dateStr 自定义日期【格式：yyyy-MM-dd】
 @return 返回文件路径
 */
-(NSString *)getLogPathWithDate:(NSString *)dateStr;


///设置上传的日志文件名称
-(NSString *)zm_getUpdateLogFileName;

///上传文件
-(void)zm_updateFileWithUpName:(NSString *)upFileName;

#pragma mark - ZipArchive

/**
 *  压缩上传日志
 *
 *  @param resultDic 包含获取日期的字典
 *  @param upFileName 上传服务器的文件名称
 */
- (void)zm_uploadZipFile:(NSDictionary*)resultDic upFileName:(NSString *)upFileName;

// 计算目录大小
-(CGFloat)zm_calculatorFileSizeAtPath:(NSString *)path;

@end




