//
//  ZMAliOSSManager.m
//  RequestAndLogManager
//  Access:LTAIAKipzmBg5CKk
//
//  Created by chenzm on 2018/9/29.
//  Copyright © 2018年 chenzm. All rights reserved.
//

#import "ZMAliOSSManager.h"

@implementation OSSTestUtils
+ (void)cleanBucket: (NSString *)bucket with: (OSSClient *)client {
    //delete object
    OSSGetBucketRequest *listObject = [OSSGetBucketRequest new];
    listObject.bucketName = bucket;
    listObject.maxKeys = 1000;
    OSSTask *listObjectTask = [client getBucket:listObject];
    [[listObjectTask continueWithBlock:^id(OSSTask * task) {
        OSSGetBucketResult * listObjectResult = task.result;
        for (NSDictionary *dict in listObjectResult.contents) {
            NSString * objectKey = [dict objectForKey:@"Key"];
            NSLog(@"delete object %@", objectKey);
            OSSDeleteObjectRequest * deleteObj = [OSSDeleteObjectRequest new];
            deleteObj.bucketName = bucket;
            deleteObj.objectKey = objectKey;
            [[client deleteObject:deleteObj] waitUntilFinished];
        }
        return nil;
    }] waitUntilFinished];
    
    //delete multipart uploads
    OSSListMultipartUploadsRequest *listMultipartUploads = [OSSListMultipartUploadsRequest new];
    listMultipartUploads.bucketName = bucket;
    listMultipartUploads.maxUploads = 1000;
    OSSTask *listMultipartUploadsTask = [client listMultipartUploads:listMultipartUploads];
    
    [[listMultipartUploadsTask continueWithBlock:^id(OSSTask *task) {
        OSSListMultipartUploadsResult * result = task.result;
        for (NSDictionary *dict in result.uploads) {
            NSString * uploadId = [dict objectForKey:@"UploadId"];
            NSString * objectKey = [dict objectForKey:@"Key"];
            NSLog(@"delete multipart uploadId %@", uploadId);
            OSSAbortMultipartUploadRequest *abort = [OSSAbortMultipartUploadRequest new];
            abort.bucketName = bucket;
            abort.objectKey = objectKey;
            abort.uploadId = uploadId;
            [[client abortMultipartUpload:abort] waitUntilFinished];
        }
        return nil;
    }] waitUntilFinished];
    //delete bucket
    OSSDeleteBucketRequest *deleteBucket = [OSSDeleteBucketRequest new];
    deleteBucket.bucketName = bucket;
    [[client deleteBucket:deleteBucket] waitUntilFinished];
}

+ (void) putTestDataWithKey: (NSString *)key withClient: (OSSClient *)client withBucket: (NSString *)bucket
{
    NSString *objectKey = key;
    NSString *filePath = [[NSString oss_documentDirectory] stringByAppendingPathComponent:objectKey];
    NSURL * fileURL = [NSURL fileURLWithPath:filePath];
    
    OSSPutObjectRequest * request = [OSSPutObjectRequest new];
    request.bucketName = bucket;
    request.objectKey = objectKey;
    request.uploadingFileURL = fileURL;
    request.objectMeta = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    
    OSSTask * task = [client putObject:request];
    [task waitUntilFinished];
}

@end



@interface ZMAliOSSManager(){
    OSSFederationToken *_token;
}

///客户端
@property(nonatomic,strong)OSSClient *client;


@end

//阿里云oss配置
#define kAccesskey          @"*****"
#define kSecretkey          @"*****"
#define kEndpoint             @"http://oss-cn-shenzhen.aliyuncs.com"
#define kBucketName           @"guawa-v3"


#define kPrivateBucketName    @"*****"


#define kOSS_STSTokenUrl      @"http://*.*.*.*:*/sts/getsts"
#define kSecurityToken        @"********"

#define OSS_IMAGE_KEY         @"*****"
#define OSS_MULTIPART_UPLOADKEY @"*****"
@implementation ZMAliOSSManager

+(ZMAliOSSManager *)shareManager{
    static ZMAliOSSManager *pay = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        pay = [[ZMAliOSSManager alloc]init];
    });
    return pay;
}


///设置联盟令牌
- (void)zm_setUpFederationToken{
    NSURL * url = [NSURL URLWithString:kOSS_STSTokenUrl];
    NSURLRequest * request = [NSURLRequest requestWithURL:url];
    OSSTaskCompletionSource * tcs = [OSSTaskCompletionSource taskCompletionSource];
    NSURLSession * session = [NSURLSession sharedSession];
    NSURLSessionDataTask * dataTask = [session dataTaskWithRequest:request
                                                 completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                                     if (!error) {
                                                         [tcs setResult:data];
                                                     }else{
                                                         NSLog(@"%@",error);
                                                     }
                                                 }];
    [dataTask resume];
    [tcs.task waitUntilFinished];
    
    NSDictionary * result = [NSJSONSerialization JSONObjectWithData:tcs.task.result
                                                            options:kNilOptions
                                                              error:nil];
    NSLog(@"result: %@", result);
    _token = [OSSFederationToken new];
    _token.tAccessKey = result[@"AccessKeyId"];
    _token.tSecretKey = result[@"AccessKeySecret"];
    _token.tToken = result[@"SecurityToken"];
    _token.expirationTimeInGMTFormat = result[@"Expiration"];
    NSLog(@"tokenInfo: %@", _token);
    
}

///初始化配置
-(void)zm_configClient{
    //执行该方法，开启日志记录
    [OSSLog enableLog];
    
    // 明文设置secret的方式建议只在测试时使用
    id<OSSCredentialProvider> provider = [self zm_getCredentialProviderWithType:0];
    //访问配置
    OSSClientConfiguration * conf = [OSSClientConfiguration new];
    // 网络请求遇到异常失败后的重试次数
    conf.maxRetryCount = 3;
    // 网络请求的超时时间
    conf.timeoutIntervalForRequest = 30;
    // 允许资源传输的最长时间
    conf.timeoutIntervalForResource = 24 * 60 * 60;
    
    //初始化OSSClient，使用自定义设置
    _client = [[OSSClient alloc] initWithEndpoint:kEndpoint credentialProvider:provider clientConfiguration:conf];
    
    
    //签名公开的访问URL
    OSSTask * task = [self zm_signInWithType:1 bucketName:kBucketName objectKey:nil];
    NSLog(@"publicURL:%@",task.result);
    
}

///STS鉴权模式
-(void)forFederationCredentialProvider{
    id<OSSCredentialProvider> provider = [self zm_getCredentialProviderWithType:2];
    [self headObjectWithBackgroundSessionIdentifier:@"com.aliyun.testcases.federationprovider.identifier" provider:provider];
}


///自签名模式
- (void)customSignerCredentialProvider{
    id<OSSCredentialProvider> provider = [self zm_getCredentialProviderWithType:3];
    
    [self headObjectWithBackgroundSessionIdentifier:@"com.aliyun.testcases.customsignercredentialprovider.identifier" provider:provider];
}

- (void)headObjectWithBackgroundSessionIdentifier:(nonnull NSString *)identifier provider:(id<OSSCredentialProvider>)provider{
    
    OSSClientConfiguration *config = [OSSClientConfiguration new];
    config.backgroundSesseionIdentifier = identifier;
    config.enableBackgroundTransmitService = YES;
    
    OSSClient *client = [[OSSClient alloc] initWithEndpoint:kEndpoint credentialProvider:provider];
    OSSCreateBucketRequest *createBucket1 = [OSSCreateBucketRequest new];
    createBucket1.bucketName = kPrivateBucketName;
    [[client createBucket:createBucket1] waitUntilFinished];
    OSSPutObjectRequest * put = [OSSPutObjectRequest new];
    put.bucketName = kPrivateBucketName;
    put.objectKey = OSS_IMAGE_KEY;
    put.uploadingFileURL = [[NSBundle mainBundle] URLForResource:@"hasky" withExtension:@"jpeg"];
    [[client putObject:put] waitUntilFinished];
    
    OSSHeadObjectRequest *request = [OSSHeadObjectRequest new];
    request.bucketName = kPrivateBucketName;
    request.objectKey = OSS_IMAGE_KEY;
    OSSTask *task = [client headObject:request];
    [task waitUntilFinished];
    
    NSLog(@"error:%@",task.error);
    [OSSTestUtils cleanBucket:kPrivateBucketName with:client];
}

#pragma mark -
#pragma mark - 上传文件

/**
 简单上传
 @param localPath 本地文件路径
 @param fileName 要保存的ali服务器文件名称
 */
-(void)zm_putResourceWithLocalFilePath:(NSString *)localPath fileName:(NSString *)fileName response:(void(^)(BOOL isSuccess,NSString * resultUrl))response{
    if (!localPath) {
        return;
    }
    OSSPutObjectRequest * put = [OSSPutObjectRequest new];
    put.bucketName = kBucketName;
    //保存在ali服务器的文件路径+文件名
    NSString *objectKeys = nil;
    if (fileName) {
        objectKeys = [NSString stringWithFormat:@"%@/%@",kAliPath,fileName];
    }else{
        objectKeys = [NSString stringWithFormat:@"%@/%@.txt",kAliPath,[self getTimeNow]];
    }
    put.objectKey = objectKeys;
    // 直接上传NSData
    //    put.uploadingData = [path dataUsingEncoding:NSUTF8StringEncoding];
    //根据文件路径上传文件
    put.uploadingFileURL = [NSURL fileURLWithPath:localPath];
    
    //进度设置，可选
    put.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        // 当前上传段长度、当前已经上传总长度、一共需要上传的总长度
        NSLog(@"%lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
    };
    
    // 以下可选字段的含义参考： https://docs.aliyun.com/#/pub/oss/api-reference/object&PutObject
    //    // 设置Content-Type，可选
    //     put.contentType = @"application/octet-stream";
    //    // 设置MD5校验，可选 设置Content-Md5，OSS会用之检查消息内容是否与发送时一致
    //    put.contentMd5 = [OSSUtil base64Md5ForFilePath:@"<filePath>"]; // 如果是文件路径
    //    // put.contentMd5 = [OSSUtil base64Md5ForData:<NSData *>]; // 如果是二进制数据
    
    // put.contentEncoding = @"";
    // put.contentDisposition = @"";
    // put.objectMeta = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil]; // 可以在上传时设置元信息或者其他HTTP头部
    
    
    OSSTask * putTask = [_client putObject:put];
    [putTask continueWithBlock:^id(OSSTask *task) {
        task = [self zm_signInWithType:1 bucketName:kBucketName objectKey:objectKeys];
        NSLog(@"objectKey: %@", put.objectKey);
        if (!task.error) {
            NSLog(@"上传对象成功!\nurl:%@",task.result);
            response(YES,task.result);
        } else {
            NSLog(@"上传对象失败, error: %@" , task.error);
            response(NO,nil);
        }
        return nil;
    }];
    
    // 可以等待任务完成
    // [putTask waitUntilFinished];
    
    // [put cancel];
}


/**
 追加上传
 
 @param fileName 文件名称
 */
-(void)appendUploadWithFilePath:(NSString *)fileName{
    OSSDeleteObjectRequest * delete = [OSSDeleteObjectRequest new];
    delete.bucketName = kPrivateBucketName;
    delete.objectKey = @"appendObject";
    OSSTask * task = [_client deleteObject:delete];
    [[task continueWithBlock:^id(OSSTask *task) {
        OSSDeleteObjectResult * result = task.result;
        if (task.error) {
            NSLog(@"错误：%@",task.error);
        }else{
            NSLog(@"result：%@",result);
        }
        return nil;
    }] waitUntilFinished];
    
    NSString *filePath = [[NSString oss_documentDirectory] stringByAppendingPathComponent:fileName];
    OSSAppendObjectRequest * request = [OSSAppendObjectRequest new];
    request.bucketName = kPrivateBucketName;
    request.objectKey = @"appendObject";
    request.appendPosition = 0;
    request.uploadingFileURL = [NSURL fileURLWithPath:filePath];
    request.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"%lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
    };
    
    __block int64_t nextAppendPosition = 0;
    __block NSString *lastCrc64ecma;
    task = [_client appendObject:request];
    [[task continueWithBlock:^id(OSSTask *task) {
        OSSAppendObjectResult * result = task.result;
        nextAppendPosition = result.xOssNextAppendPosition;
        lastCrc64ecma = result.remoteCRC64ecma;
        return nil;
    }] waitUntilFinished];
    
    request.bucketName = kPrivateBucketName;
    request.objectKey = @"appendObject";
    request.appendPosition = nextAppendPosition;
    request.uploadingFileURL = [NSURL fileURLWithPath:filePath];
    request.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"%lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
    };
    
    task = [_client appendObject:request withCrc64ecma:lastCrc64ecma];
    [[task continueWithBlock:^id(OSSTask *task) {
        if (task.error) {
            NSLog(@"错误：%@",task.error);
        }
        return nil;
    }] waitUntilFinished];
}


///断点上传
- (void)multipartUploadWithFileName:(NSString *)fileName success:(void (^_Nullable)(id))success failure:(void (^_Nullable)(NSError*))failure {
    if (!fileName) {
        return;
    }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // 获取沙盒的cache路径
        NSString *cachesDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
        
        // 获取本地大文件url
        NSURL *fileURL = [[NSBundle mainBundle] URLForResource:fileName withExtension:@"zip"];
        
        OSSResumableUploadRequest * resumableUpload = [OSSResumableUploadRequest new];
        //// 设置bucket名称
        resumableUpload.bucketName = kBucketName;
        // 设置object key
        resumableUpload.objectKey = @"oss-ios-demo-big-file";
        // 设置要上传的文件url
        resumableUpload.uploadingFileURL = fileURL;
        // 设置content-type
        resumableUpload.contentType = @"application/octet-stream";
        // 设置分片大小
        resumableUpload.partSize = 102400;
        // 设置分片信息的本地存储路径
        resumableUpload.recordDirectoryPath = cachesDir;
        
        // 设置metadata
        resumableUpload.completeMetaHeader = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
        
        // 设置上传进度回调
        resumableUpload.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
            NSLog(@"progress: %lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
        };
        
        //
        OSSTask * resumeTask = [_client resumableUpload:resumableUpload];
        // 阻塞当前线程直到上传任务完成
        [resumeTask waitUntilFinished];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (resumeTask.result) {
                success(resumeTask.result);
            } else {
                failure(resumeTask.error);
            }
        });
    });
}

///分片上传并校验
- (void)multipartUpload{
    __block NSString * uploadId = nil;
    __block NSMutableArray * partInfos = [NSMutableArray array];
    OSSInitMultipartUploadRequest * init = [OSSInitMultipartUploadRequest new];
    init.bucketName = kPrivateBucketName;
    init.objectKey = OSS_MULTIPART_UPLOADKEY;
    init.contentType = @"application/octet-stream";
    init.objectMeta = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"value1", @"x-oss-meta-name1", nil];
    OSSTask * task = [_client multipartUploadInit:init];
    [[task continueWithBlock:^id(OSSTask *task) {
        OSSInitMultipartUploadResult * result = task.result;
        uploadId = result.uploadId;
        return nil;
    }] waitUntilFinished];
    
    int chuckCount = 7;
    for (int i = 0; i < chuckCount; i++)
    {
        OSSUploadPartRequest * uploadPart = [OSSUploadPartRequest new];
        uploadPart.bucketName = kPrivateBucketName;
        uploadPart.objectkey = OSS_MULTIPART_UPLOADKEY;
        uploadPart.uploadId = uploadId;
        uploadPart.partNumber = i+1; // part number start from 1
        NSString * filePath = [[NSString oss_documentDirectory] stringByAppendingPathComponent:@"file1m"];
        uint64_t fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil] fileSize];
        OSSLogVerbose(@" testMultipartUpload filesize: %llu", fileSize);
        uint64_t offset = fileSize / chuckCount;
        OSSLogVerbose(@" testMultipartUpload offset: %llu", offset);
        
        NSFileHandle* readHandle = [NSFileHandle fileHandleForReadingAtPath:filePath];
        [readHandle seekToFileOffset:offset * i];
        
        NSData* data;
        if (i+1 == chuckCount)
        {
            NSUInteger lastLength = offset + fileSize % chuckCount;
            data = [readHandle readDataOfLength:lastLength];
        }else
        {
            data = [readHandle readDataOfLength:offset];
        }
        
        uploadPart.uploadPartData = data;
        NSUInteger partSize = data.length;
        NSTimeInterval startUpload = [[NSDate date] timeIntervalSince1970];
        task = [_client uploadPart:uploadPart];
        [[task continueWithBlock:^id(OSSTask *task) {
            OSSUploadPartResult * result = task.result;
            
            uint64_t remoteCrc64ecma;
            NSScanner *scanner = [NSScanner scannerWithString:result.remoteCRC64ecma];
            [scanner scanUnsignedLongLong:&remoteCrc64ecma];
            if (i == 2) {
                remoteCrc64ecma += 1;
            }
            
            [partInfos addObject:[OSSPartInfo partInfoWithPartNum:i+1 eTag:result.eTag size:partSize crc64:remoteCrc64ecma]];
            return nil;
        }] waitUntilFinished];
        NSTimeInterval endUpload = [[NSDate date] timeIntervalSince1970];
        NSTimeInterval cost = endUpload - startUpload;
        OSSLogDebug(@"part num: %d  upload part cost time: %f", i, cost);
    }
    
    __block uint64_t localCrc64 = 0;
    [partInfos enumerateObjectsUsingBlock:^(OSSPartInfo *partInfo, NSUInteger idx, BOOL * _Nonnull stop) {
        if (localCrc64 == 0)
        {
            localCrc64 = partInfo.crc64;
        }else
        {
            localCrc64 = [OSSUtil crc64ForCombineCRC1:localCrc64 CRC2:partInfo.crc64 length:partInfo.size];
        }
    }];
    
    OSSCompleteMultipartUploadRequest * complete = [OSSCompleteMultipartUploadRequest new];
    complete.bucketName = kPrivateBucketName;
    complete.objectKey = OSS_MULTIPART_UPLOADKEY;
    complete.uploadId = uploadId;
    complete.partInfos = partInfos;
    complete.crcFlag = OSSRequestCRCOpen;
    
    task = [_client completeMultipartUpload:complete];
    [[task continueWithBlock:^id(OSSTask *task) {
        OSSCompleteMultipartUploadResult * result = task.result;
        uint64_t remoteCrc64ecma;
        NSScanner *scanner = [NSScanner scannerWithString:result.remoteCRC64ecma];
        [scanner scanUnsignedLongLong:&remoteCrc64ecma];
        return nil;
    }] waitUntilFinished];
}
#pragma mark -
#pragma mark - 文件下载

///下载文件
-(void)loadFileWithPath:(NSString *)filePath{
    if (!filePath) {
        return;
    }
    OSSGetObjectRequest * request = [OSSGetObjectRequest new];
    request.bucketName = kBucketName;
    //要下载的文件
    request.objectKey = filePath;
    // 可选字段
    request.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
        // 当前下载段长度、当前已经下载总长度、一共需要下载的总长度
        NSLog(@"%lld, %lld, %lld", bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
    };
    // request.range = [[OSSRange alloc] initWithStart:0 withEnd:99]; // bytes=0-99，指定范围下载
    // request.downloadToFileURL = [NSURL fileURLWithPath:@"<filepath>"]; // 如果需要直接下载到文件，需要指明目标文件地址
    OSSTask * getTask = [_client getObject:request];
    [getTask continueWithBlock:^id(OSSTask *task) {
        if (!task.error) {
            NSLog(@"下载文件成功!");
            OSSGetObjectResult * getResult = task.result;
            NSLog(@"download result: %@", getResult.downloadedData);
        } else {
            NSLog(@"下载失败, error: %@" ,task.error);
        }
        return nil;
    }];
    // [getTask waitUntilFinished];
}




#pragma mark -
#pragma mark - 授权访问

/**
 签名的访问URL
 
 如果Object的权限是公共读或者公共读写，调用这个接口对该Object签名出一个URL，可以把该URL转给第三方实现授权访问。
 @param type 1、签名公开 其他：指定有效时长的私有签名
 @param bucketName Object所在的Bucket名称
 @param objectKey Object名称
 @return 访问URL
 */
-(OSSTask *)zm_signInWithType:(NSInteger)type bucketName:(NSString *)bucketName objectKey:(NSString *)objectKey{
    
    if (!bucketName) {
        return nil;
    }
    if (!objectKey) {
        objectKey = @"";
    }
    OSSTask * task = nil;
    if (type == 1) {//公开
        task = [_client presignPublicURLWithBucketName:bucketName
                                         withObjectKey:objectKey];
    }else{
        // 限制签名   Interval:有效期限
        task = [_client presignConstrainURLWithBucketName:bucketName
                                            withObjectKey:objectKey
                                   withExpirationInterval: 30 * 60];
    }
    return task;
}



#pragma mark -
#pragma mark - 文件管理

///检查文件是否存在
-(BOOL)zm_fileValidateExit:(NSString *)bucketName bucketName:(NSString *)fileName{
    NSError * error = nil;
    BOOL isExist = [_client doesObjectExistInBucket:bucketName objectKey:fileName error:&error];
    if (!error) {
        if(isExist) {
            NSLog(@"File exists.");
            return YES;
        } else {
            NSLog(@"File not exists.");
            return NO;
        }
    } else {
        NSLog(@"Error!");
        return NO;
    }
}

/**
 复制Object
 
 源Object和目标Object必须属于同一个数据中心。
 如果拷贝操作的源Object地址和目标Object地址相同，可以修改已有Object的meta信息。
 拷贝文件大小不能超过1G，超过1G需使用Multipart Upload操作。
 */
-(void)zm_fileCopyObjectFrom:(NSString *)fromBucketName fromObjectKey:(NSString *)fromObjectKey to:(NSString *)toBucketName toObjectKey:(NSString *)toObjectKey{
    if (!fromBucketName||!fromObjectKey||!toBucketName||!toObjectKey) {
        return;
    }
    OSSCopyObjectRequest * copy = [OSSCopyObjectRequest new];
    copy.sourceBucketName = fromBucketName;
    copy.sourceObjectKey = fromObjectKey;
    
    copy.bucketName = toBucketName;
    copy.objectKey = toObjectKey;
    OSSTask * task = [_client copyObject:copy];
    [task continueWithBlock:^id(OSSTask *task) {
        if (!task.error) {
            // ...
        }
        return nil;
    }];
}

///删除Object
-(void)zm_fileDeleteObject:(NSString *)bucketName objectKey:(NSString *)objectKey{
    if (!bucketName||!objectKey) {
        return;
    }
    OSSDeleteObjectRequest * delete = [OSSDeleteObjectRequest new];
    delete.bucketName = bucketName;
    delete.objectKey = objectKey;
    OSSTask * deleteTask = [_client deleteObject:delete];
    [deleteTask continueWithBlock:^id(OSSTask *task) {
        if (!task.error) {
            // ...
        }
        return nil;
    }];
    // [deleteTask waitUntilFinished];
}

///只获取Object的Meta信息
-(void)zm_fileGetObjectMeta:(NSString *)bucketName objectKey:(NSString *)objectKey{
    if (!bucketName||!objectKey) {
        return;
    }
    
    OSSHeadObjectRequest * head = [OSSHeadObjectRequest new];
    head.bucketName = bucketName;
    head.objectKey = objectKey;
    OSSTask * headTask = [_client headObject:head];
    [headTask continueWithBlock:^id(OSSTask *task) {
        if (!task.error) {
            OSSHeadObjectResult * headResult = task.result;
            NSLog(@"all response header: %@", headResult.httpResponseHeaderFields);
            // some object properties include the 'x-oss-meta-*'s
            NSLog(@"head object result: %@", headResult.objectMeta);
        } else {
            NSLog(@"head object error: %@", task.error);
        }
        return nil;
    }];
}

#pragma mark -
#pragma mark - Bucket管理
/**
 创建bucket
 
 每个用户的Bucket数量不能超过30个。
 每个Bucket的名字全局唯一，也就是说创建的Bucket不能和其他用户已经在使用的Bucket同名，否则会创建失败。
 创建的时候可以选择Bucket ACL权限，如果不设置ACL，默认是private。
 创建成功结果返回Bucket所在数据中心。
 */
-(void)zm_bucketCreateWithName:(NSString *)bucketName{
    if (!bucketName||bucketName.length == 0) {
        return;
    }
    
    OSSCreateBucketRequest * create = [OSSCreateBucketRequest new];
    create.bucketName = bucketName;
    create.xOssACL = @"public-read";
    //    create.location = @"oss-cn-hangzhou";
    OSSTask * createTask = [_client createBucket:create];
    [createTask continueWithBlock:^id(OSSTask *task) {
        if (!task.error) {
            NSLog(@"create bucket success!");
        } else {
            NSLog(@"create bucket failed, error: %@", task.error);
        }
        return nil;
    }];
}

/**
 罗列所有bucket
 
 匿名访问不支持该操作。
 */
-(void)zm_bucketList{
    OSSGetServiceRequest * getService = [OSSGetServiceRequest new];
    OSSTask * getServiceTask = [_client getService:getService];
    [getServiceTask continueWithBlock:^id(OSSTask *task) {
        if (!task.error) {
            OSSGetServiceResult * result = task.result;
            NSLog(@"buckets: %@", result.buckets);
            NSLog(@"owner: %@, %@", result.ownerId, result.ownerDispName);
            [result.buckets enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                NSDictionary * bucketInfo = obj;
                NSLog(@"BucketName: %@", [bucketInfo objectForKey:@"Name"]);
                NSLog(@"CreationDate: %@", [bucketInfo objectForKey:@"CreationDate"]);
                NSLog(@"Location: %@", [bucketInfo objectForKey:@"Location"]);
            }];
        }
        return nil;
    }];
}

/**
 罗列bucket中的文件
 
 罗列操作必须具备访问该Bukcet的权限。
 罗列时，可以通过prefix，marker，delimiter和max-keys对list做限定，返回部分结果。
 */
-(void)zm_bucketFileWithName:(NSString *)bucketName{
    if (!bucketName||bucketName.length == 0) {
        return;
    }
    
    OSSGetBucketRequest * getBucket = [OSSGetBucketRequest new];
    getBucket.bucketName = bucketName;
    
    //    //设定结果从marker之后按字母排序的第一个开始返回
    //    getBucket.marker = @"";
    //
    //    //限定返回的object key必须以prefix作为前缀。注意使用prefix查询时，返回的key中仍会包含prefix。
    //    getBucket.prefix = @"";
    //
    //    //用于对Object名字进行分组的字符。所有名字包含指定的前缀且第一次出现delimiter字符之间的object作为一组元素: CommonPrefixes。
    //    getBucket.delimiter = @"";
    //
    //    //限定此次返回object的最大数，如果不设定，默认为100，maxkeys取值不能大于1000。
    //    getBucket.maxKeys = 20;
    
    OSSTask * getBucketTask = [_client getBucket:getBucket];
    [getBucketTask continueWithBlock:^id(OSSTask *task) {
        if (!task.error) {
            OSSGetBucketResult * result = task.result;
            NSLog(@"get bucket success!");
            for (NSDictionary * objectInfo in result.contents) {
                NSLog(@"list object: %@", objectInfo);
            }
        } else {
            NSLog(@"get bucket failed, error: %@", task.error);
        }
        return nil;
    }];
}

/**
 删除bucket
 
 只有Bucket的拥有者才能删除这个Bucket。
 为了防止误删除的发生，OSS不允许用户删除一个非空的Bucket。
 */
-(void)zm_bucketDeleteWithName:(NSString *)bucketName{
    if (!bucketName||bucketName.length == 0) {
        return;
    }
    OSSDeleteBucketRequest * delete = [OSSDeleteBucketRequest new];
    delete.bucketName = bucketName;
    OSSTask * deleteTask = [_client deleteBucket:delete];
    [deleteTask continueWithBlock:^id(OSSTask *task) {
        if (!task.error) {
            NSLog(@"delete bucket success!");
        } else {
            NSLog(@"delete bucket failed, error: %@", task.error);
        }
        return nil;
    }];
}

#pragma mark -
#pragma mark - private

/**
 证书配置   CredentialProvider协议，要求实现加签接口
 
 @param type 配置类型 1 ～ 4 默认:明文设置宜测试
 @return 返回配置完后的数据对象
 */
-(id<OSSCredentialProvider>)zm_getCredentialProviderWithType:(NSInteger)type{
    id<OSSCredentialProvider> provider = nil;
    switch (type) {
        case 1:{
            //直接访问鉴权服务器（推荐，token过期后可以自动更新）
            provider = [[OSSAuthCredentialProvider alloc] initWithAuthServerUrl:kOSS_STSTokenUrl];
        }break;
        case 2:{
            //STS令牌的凭据提供者
            provider = [[OSSStsTokenCredentialProvider alloc] initWithAccessKeyId:kAccesskey secretKeyId:kSecretkey securityToken:kSecurityToken];
        }break;
        case 3:{
            //自定义签名凭证提供者
            provider = [[OSSCustomSignerCredentialProvider alloc] initWithImplementedSigner:^NSString *(NSString *contentToSign, NSError *__autoreleasing *error) {
                OSSFederationToken *token = [OSSFederationToken new];
                token.tAccessKey = kAccesskey;
                token.tSecretKey = kSecretkey;
                //CredentialProvider协议，要求实现加签接口
                NSString *signedContent = [OSSUtil sign:contentToSign withToken:token];
                return signedContent;
            }];
        }break;
        case 4:{
            //用户自实现的通过获取FederationToken来加签的加签器
            provider = [[OSSFederationCredentialProvider alloc]initWithFederationTokenGetter:^OSSFederationToken * _Nullable{
                return _token;
            }];
        }break;
        default:{
            // 明文设置secret的方式建议只在测试时使用，更多鉴权模式参考后面链接给出的官网完整文档的`访问控制`章节
            provider = [[OSSPlainTextAKSKPairCredentialProvider alloc] initWithPlainTextAccessKey:kAccesskey secretKey:kSecretkey];
            
        }break;
    }
    
    //    //构造请求过程中做加签
    //    OSSCredentialProvider *provider = nil;
    //    [[OSSSignerInterceptor alloc]initWithCredentialProvider:provider];
    
    return provider;
}

/**
 *  返回当前时间
 */
- (NSString *)getTimeNow{
    NSString* date;
    NSDateFormatter * formatter = [[NSDateFormatter alloc ] init];
    [formatter setDateFormat:@"YYYYMMddhhmmssSSS"];
    date = [formatter stringFromDate:[NSDate date]];
    //取出个随机数
    int last = arc4random() % 10000;
    NSString *timeNow = [[NSString alloc] initWithFormat:@"%@-%i", date,last];
    NSLog(@"%@", timeNow);
    return timeNow;
}

@end

