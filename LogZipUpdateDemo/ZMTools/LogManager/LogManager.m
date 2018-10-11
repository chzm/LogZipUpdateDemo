//
//  LogManager.m
//  LogFileDemo
//
//  Created by xgao on 17/3/9.
//  Copyright © 2017年 chenzm. All rights reserved.
//

#import "LogManager.h"
#import <ZipArchive.h>
#import "ZMAliOSSManager.h"

@interface LogManager()

// 日期格式化
@property (nonatomic,retain) NSDateFormatter* dateFormatter;
// 时间格式化
@property (nonatomic,retain) NSDateFormatter* timeFormatter;

// 日志的目录路径
@property (nonatomic,copy) NSString* basePath;

@end

@implementation LogManager

/**
 *  获取单例实例
 *
 *  @return 单例实例
 */
+ (instancetype) sharedInstance{
    
    static LogManager* instance = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (!instance) {
            instance = [[LogManager alloc]init];
        }
    });
    
    return instance;
}

// 获取当前时间
+ (NSDate*)getCurrDate{
    
    NSDate *date = [NSDate date];
    NSTimeZone *zone = [NSTimeZone systemTimeZone];
    NSInteger interval = [zone secondsFromGMTForDate: date];
    NSDate *localeDate = [date dateByAddingTimeInterval: interval];
    
    return localeDate;
}

#pragma mark - Init

- (instancetype)init{
    
    self = [super init];
    if (self) {
        
        // 创建日期格式化
        NSDateFormatter* dateFormatter = [[NSDateFormatter alloc]init];
        [dateFormatter setDateFormat:kLogFileNameFormat];
        // 设置时区，解决8小时
        [dateFormatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
        self.dateFormatter = dateFormatter;
        
        // 创建时间格式化
        NSDateFormatter* timeFormatter = [[NSDateFormatter alloc]init];
        [timeFormatter setDateFormat:@"yyyy/MM/dd HH:mm:ss"];
        [timeFormatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
        self.timeFormatter = timeFormatter;
        
        // 日志的目录路径
        self.basePath = [NSString stringWithFormat:@"%@%@",NSHomeDirectory(),kCacheLogFilePath];
    }
    return self;
}

#pragma mark - Method

///设置上传的日志文件名称
-(NSString *)zm_getUpdateLogFileName{
    NSString *memberId = @"123";
    NSString *recomendCode = @"CODE";
    if (memberId&&memberId.length > 0 && recomendCode&&recomendCode.length > 0) {
        NSString *str = [NSString stringWithFormat:@"iosLog[%@(%@)] ",recomendCode,memberId];
        return str;
    }else{
        return nil;
    }
}


/**
 *  写入日志
 *
 *  @param module 模块名称
 *  @param logStr 日志信息,动态参数
 */
- (void)logInfo:(NSString*)module logStr:(NSString*)logStr, ...{
#pragma mark - 获取参数
    
    NSMutableString* parmaStr = [NSMutableString string];
    // 声明一个参数指针
    va_list paramList;
    // 获取参数地址，将paramList指向logStr
    va_start(paramList, logStr);
    id arg = logStr;
    
    @try {
        // 遍历参数列表
        while (arg) {
            [parmaStr appendString:arg];
            // 指向下一个参数，后面是参数类似
            arg = va_arg(paramList, NSString*);
        }
        
    } @catch (NSException *exception) {
        
        [parmaStr appendString:@"【记录日志异常】"];
    } @finally {
        
        // 将参数列表指针置空
        va_end(paramList);
    }
    
#pragma mark - 写入日志
    
    // 异步执行
    dispatch_async(dispatch_queue_create("writeLog", nil), ^{
        
        NSString* filePath = [self getLogPathWithDate:nil];
        // [时间]-[模块]-日志内容
        NSString* timeStr = [self.timeFormatter stringFromDate:[LogManager getCurrDate]];
        NSString* writeStr = [NSString stringWithFormat:@"[%@]-[%@]-%@\n",timeStr,module,parmaStr];
        
        // 写入数据
        [self writeFile:filePath stringData:writeStr];
        
        NSLog(@"写入日志:%@",filePath);
    });
}

/**
 读取文件信息
 @param fileName 文件路径
 */
- (NSString *)readFile:(NSString *)fileName{
    NSString *filePath = [self getLogPathWithDate:fileName];
    NSData *data = [NSData dataWithContentsOfFile:filePath];
    NSString *logStr = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
    return logStr;
}

/**
 获取对应日期做为文件名
 @param dateStr 自定义日期【格式：yyyy-MM-dd】
 @return 返回文件路径
 */
-(NSString *)getLogPathWithDate:(NSString *)dateStr{
    NSString* fileName = nil;
    if(dateStr&&dateStr.length > 0){
        fileName = dateStr;
    }else{
        fileName = [self.dateFormatter stringFromDate:[NSDate date]];
    }
    NSString* filePath = [NSString stringWithFormat:@"%@%@",self.basePath,fileName];
    return filePath;
}

/**
 移除文件
 @param cacheNum 还需要保存的数量
 */
-(void)deleteFileWithCacheNum:(NSInteger)cacheNum{
    
    cacheNum = cacheNum == 0?1:cacheNum;
    
    NSString *DocumentsPath = [NSHomeDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@",kGetLogFilePath]];
    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtPath:DocumentsPath];
    NSInteger allCount = [self getLocalFileTotalNum];
    NSInteger currentCount = 0;
    NSString *dateStr = [self log_changeStrFromDate:[NSDate date] dateFormat:kLogFileNameFormat];
    for (NSString *fileName in enumerator) {
        if (currentCount <= allCount - cacheNum - 1) {
            if (![fileName isEqualToString:dateStr]) {//当前的日志不删除
                [[NSFileManager defaultManager] removeItemAtPath:[DocumentsPath stringByAppendingPathComponent:fileName] error:nil];
            }
        }
        currentCount ++;
    }
}

///获取最早的一个文件名称
-(NSString *)getOldestFileName{
    [self deleteFileWithCacheNum:2];
    NSString *DocumentsPath = [NSHomeDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@",kGetLogFilePath]];
    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtPath:DocumentsPath];
    NSString *lastFileStr = nil;
    
    NSString *oldDate = nil;
    NSString *currentDate = nil;
    for (NSString *fileName in enumerator) {
        currentDate = fileName;
        if (oldDate.length > 0) {
            long long curLL = [self log_changeLLFromString:currentDate dateFormat:kLogFileNameFormat];
            long long oldLL = [self log_changeLLFromString:oldDate dateFormat:kLogFileNameFormat];
            if (curLL < oldLL) {
                lastFileStr = fileName;
            }
        }else{
            lastFileStr = fileName;
        }
        oldDate = fileName;
    }
    return lastFileStr;
}

///获取最近的一个文件名称
-(NSString *)getLastFileName{
    [self deleteFileWithCacheNum:2];
    NSString *DocumentsPath = [NSHomeDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@",kGetLogFilePath]];
    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtPath:DocumentsPath];
    NSString *lastFileStr = nil;
    
    NSString *oldDate = nil;
    NSString *currentDate = nil;
    for (NSString *fileName in enumerator) {
        currentDate = fileName;
        if (oldDate.length > 0) {
            long long curLL = [self log_changeLLFromString:currentDate dateFormat:kLogFileNameFormat];
            long long oldLL = [self log_changeLLFromString:oldDate dateFormat:kLogFileNameFormat];
            if (curLL > oldLL) {
                lastFileStr = fileName;
            }
        }else{
            lastFileStr = fileName;
        }
        oldDate = fileName;
    }
    return lastFileStr;
}


///获取本地文件的总数量
-(NSInteger)getLocalFileTotalNum{
    NSString *DocumentsPath = [NSHomeDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@",kGetLogFilePath]];
    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtPath:DocumentsPath];
    NSInteger allCount = 0;
    NSString *str = nil;
    for (NSString *fileName in enumerator) {
        str = fileName;
        allCount ++;
    }
    return allCount;
}

///上传文件
-(void)zm_updateFileWithUpName:(NSString *)upFileName{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *dateStr = [self log_changeStrFromDate:[NSDate date] dateFormat:kLogFileNameFormat];
        NSString *fileNameStr = [self getOldestFileName];
        if (![dateStr isEqualToString:fileNameStr]) {
            ///获取文本内容
            NSString *fileContent = [self readFile:fileNameStr];
            if (fileContent&&fileContent.length>0) {
                //获取文件路径
                NSString *path = [self getLogPathWithDate:fileNameStr];
                NSString *upFileNameStr = upFileName.length>0?upFileName:@"";
                if (upFileNameStr&&upFileNameStr.length > 0) {
                    upFileNameStr = [NSString stringWithFormat:@"%@%@",upFileNameStr,fileNameStr];
                }
                __weak typeof(self) weakself = self;
                [[ZMAliOSSManager shareManager] zm_putResourceWithLocalFilePath:path fileName:upFileNameStr response:^(BOOL isSuccess, NSString *resultUrl) {
                    if (isSuccess == YES) {
                        [weakself deleteFileWithCacheNum:1];
                    }
                }];
            }
        }
    });
}

#pragma mark - ZipArchive

/**
 *  处理是否需要上传日志
 *
 *  @param resultDic 包含获取日期的字典
 *  @param upFileName 上传服务器的文件名称
 */
- (void)zm_uploadZipFile:(NSDictionary*)resultDic upFileName:(NSString *)upFileName{
    if (!resultDic) {
        return;
    }
    
    // 0不拉取，1拉取N天，2拉取全部
    int type = [resultDic[@"type"] intValue];
    // 压缩文件是否创建成功
    BOOL created = NO;
    if (type == 1) {
        // 拉取指定日期的
        
        // "dates": ["2017-03-01", "2017-03-11"]
        NSArray* dates = resultDic[@"dates"];
        
        // 压缩日志
        created = [self compressLog:dates];
    }else if(type == 2){
        // 拉取全部
        
        // 压缩日志
        created = [self compressLog:nil];
    }
    
    if (created) {
        
        // 压缩包文件路径
        NSString * zipFile = [self getZipFilePathName];
        NSString *fileName = nil;
        if (upFileName&&upFileName.length > 0) {
            fileName = [NSString stringWithFormat:@"%@.zip",upFileName];
        }else{
            fileName = kZipFileName;
        }
        // 上传
        [[ZMAliOSSManager shareManager] zm_putResourceWithLocalFilePath:zipFile fileName:fileName response:^(BOOL isSuccess, NSString *resultUrl) {
            if (isSuccess == YES) {
                // 删除日志压缩文件
                [self deleteZipFile];
            }
        }];
    }
}

/**
 *  压缩日志
 *
 *  @param dates 日期时间段，空代表全部
 *
 *  @return 执行结果
 */
- (BOOL)compressLog:(NSArray*)dates{
    
    // 先清理几天前的日志
    [self clearExpiredLog];
    
    // 获取日志目录下的所有文件
    NSArray* files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.basePath error:nil];
    // 压缩包文件路径
    NSString * zipFile = [self getZipFilePathName];
    
    ZipArchive* zip = [[ZipArchive alloc] init];
    // 创建一个zip包
    BOOL created = [zip CreateZipFile2:zipFile];
    if (!created) {
        // 关闭文件
        [zip CloseZipFile2];
        return NO;
    }
    
    if (dates) {
        // 拉取指定日期的
        for (NSString* fileName in files) {
            if ([dates containsObject:fileName]) {
                // 将要被压缩的文件
                NSString *file = [self.basePath stringByAppendingString:fileName];
                // 判断文件是否存在
                if ([[NSFileManager defaultManager] fileExistsAtPath:file]) {
                    // 将日志添加到zip包中
                    [zip addFileToZip:file newname:fileName];
                }
            }
        }
    }else{
        // 全部
        for (NSString* fileName in files) {
            // 将要被压缩的文件
            NSString *file = [self.basePath stringByAppendingString:fileName];
            // 判断文件是否存在
            if ([[NSFileManager defaultManager] fileExistsAtPath:file]) {
                // 将日志添加到zip包中
                [zip addFileToZip:file newname:fileName];
            }
        }
    }
    
    // 关闭文件
    [zip CloseZipFile2];
    return YES;
}


///清空过期的日志
- (void)clearExpiredLog{
    
    // 获取日志目录下的所有文件
    NSArray* files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.basePath error:nil];
    for (NSString* file in files) {
        NSDate* date = [self.dateFormatter dateFromString:file];
        if (date) {
            NSTimeInterval oldTime = [date timeIntervalSince1970];
            NSTimeInterval currTime = [[LogManager getCurrDate] timeIntervalSince1970];
            NSTimeInterval second = currTime - oldTime;
            int day = (int)second / (24 * 3600);
            if (day >= kLogMaxSaveDay) {
                // 删除该文件
                [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@",self.basePath,file] error:nil];
                NSLog(@"[%@]日志文件已被删除！",file);
            }
        }
    }
}


/**
 *  删除日志压缩文件
 */
- (void)deleteZipFile{
    NSString* zipFilePath = [self.basePath stringByAppendingString:kZipFileName];
    if ([[NSFileManager defaultManager] fileExistsAtPath:zipFilePath]) {
        [[NSFileManager defaultManager] removeItemAtPath:zipFilePath error:nil];
    }
}

///获取压缩包文件路径
-(NSString *)getZipFilePathName{
    NSString * zipFileName = [self.basePath stringByAppendingString:kZipFileName] ;
    return zipFileName;
}



#pragma mark - Private


/**
 *  写入字符串到指定文件，默认追加内容
 *
 *  @param filePath   文件路径
 *  @param stringData 待写入的字符串
 */
- (void)writeFile:(NSString*)filePath stringData:(NSString*)stringData{
    
    // 待写入的数据
    NSData* writeData = [stringData dataUsingEncoding:NSUTF8StringEncoding];
    // NSFileManager 用于处理文件
    BOOL createPathOk = YES;
    if (![[NSFileManager defaultManager] fileExistsAtPath:[filePath stringByDeletingLastPathComponent] isDirectory:&createPathOk]) {
        // 目录不存先创建
        [[NSFileManager defaultManager] createDirectoryAtPath:[filePath stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
    }
    if(![[NSFileManager defaultManager] fileExistsAtPath:filePath]){
        // 文件不存在，直接创建文件并写入
        [writeData writeToFile:filePath atomically:NO];
    }else{
        
        // NSFileHandle 用于处理文件内容
        // 读取文件到上下文，并且是更新模式
        NSFileHandle* fileHandler = [NSFileHandle fileHandleForUpdatingAtPath:filePath];
        
        // 跳到文件末尾
        [fileHandler seekToEndOfFile];
        
        // 追加数据
        [fileHandler writeData:writeData];
        
        // 关闭文件
        [fileHandler closeFile];
    }
}

// 计算目录大小
-(CGFloat)zm_calculatorFileSizeAtPath:(NSString *)path{
    // 利用NSFileManager实现对文件的管理
    NSFileManager *manager = [NSFileManager defaultManager];
    CGFloat size = 0;
    if ([manager fileExistsAtPath:path]) {
        // 计算文件大小
        size = [manager attributesOfItemAtPath:path error:nil].fileSize;
        
        if (size < 1024.0) {
            NSLog(@"文件大小:%.0lfByte",size);
        }else if (size < 1024.0*1024.0){
            CGFloat si = size / 1024.0;
            NSLog(@"文件大小:%.0lfKB",si);
        }else{
            CGFloat si = size / 1024.0 / 1024.0;
            NSLog(@"文件大小:%.0lfMB",si);
        }
        // 将大小转化为M
        size = size / 1024.0 / 1024.0;
    }
    return size;
}

/**
 字符串（Str）转换成LL
 @param theTime 字符串时间
 @param dateFormat 转化格式
 @return 返回时间戳
 */
- (long long)log_changeLLFromString:(NSString *)theTime dateFormat:(NSString *)dateFormat{
    //装换为时间戳
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateStyle:NSDateFormatterMediumStyle];
    [formatter setTimeStyle:NSDateFormatterShortStyle];
    [formatter setDateFormat:dateFormat];
    NSDate* dateTodo = [formatter dateFromString:theTime];
    return [dateTodo timeIntervalSince1970];
}

/**
 将NSDate转成字符串（Str）
 
 @param date 日期
 @param dateFormat 转化格式
 @return 返回字符串时间
 */
- (NSString *)log_changeStrFromDate:(NSDate *)date dateFormat:(NSString *)dateFormat{
    NSDateFormatter* fmt = [[NSDateFormatter alloc] init];
    fmt.locale = [NSLocale systemLocale];
    fmt.dateFormat = dateFormat;
    NSString * dateStr = [fmt stringFromDate:date];
    return dateStr;
}



@end


