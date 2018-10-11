//
//  ZMAliOSSManager.h
//  RequestAndLogManager
//  Secret:tVSKqSptKrIQGd8natpyM0c71YtFXG
//
//  Created by chenzm on 2018/9/29.
//  Copyright © 2018年 chenzm. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <AliyunOSSiOS/OSSService.h>


#define kAliPath @"iOSLog"


@interface OSSTestUtils : NSObject
+ (void)cleanBucket: (NSString *)bucket with: (OSSClient *)client;
+ (void) putTestDataWithKey: (NSString *)key withClient: (OSSClient *)client withBucket: (NSString *)bucket;
@end



@interface ZMAliOSSManager : NSObject

///单粒
+(ZMAliOSSManager *)shareManager;


///设置联盟令牌
- (void)zm_setUpFederationToken;

///初始化配置
-(void)zm_configClient;

/**
 简单上传
 @param localPath 本地文件路径
 @param fileName 要保存的ali服务器文件名称
 */
-(void)zm_putResourceWithLocalFilePath:(NSString *)localPath fileName:(NSString *)fileName response:(void(^)(BOOL isSuccess,NSString * resultUrl))response;

#pragma mark -
#pragma mark - 授权访问



#pragma mark -
#pragma mark - 文件管理

///检查文件是否存在
-(BOOL)zm_fileValidateExit:(NSString *)bucketName bucketName:(NSString *)fileName;

/**
 复制Object
 
 源Object和目标Object必须属于同一个数据中心。
 如果拷贝操作的源Object地址和目标Object地址相同，可以修改已有Object的meta信息。
 拷贝文件大小不能超过1G，超过1G需使用Multipart Upload操作。
 */
-(void)zm_fileCopyObjectFrom:(NSString *)fromBucketName fromObjectKey:(NSString *)fromObjectKey to:(NSString *)toBucketName toObjectKey:(NSString *)toObjectKey;

///删除Object
-(void)zm_fileDeleteObject:(NSString *)bucketName objectKey:(NSString *)objectKey;

///只获取Object的Meta信息
-(void)zm_fileGetObjectMeta:(NSString *)bucketName objectKey:(NSString *)objectKey;

#pragma mark - Bucket管理

/**
 创建bucket
 
 每个用户的Bucket数量不能超过30个。
 每个Bucket的名字全局唯一，也就是说创建的Bucket不能和其他用户已经在使用的Bucket同名，否则会创建失败。
 创建的时候可以选择Bucket ACL权限，如果不设置ACL，默认是private。
 创建成功结果返回Bucket所在数据中心。
 */
-(void)zm_bucketCreateWithName:(NSString *)bucketName;

/**
 罗列所有bucket
 
 匿名访问不支持该操作。
 */
-(void)zm_bucketList;

/**
 罗列bucket中的文件
 
 罗列操作必须具备访问该Bukcet的权限。
 罗列时，可以通过prefix，marker，delimiter和max-keys对list做限定，返回部分结果。
 */
-(void)zm_bucketFileWithName:(NSString *)bucketName;

/**
 删除bucket
 
 只有Bucket的拥有者才能删除这个Bucket。
 为了防止误删除的发生，OSS不允许用户删除一个非空的Bucket。
 */
-(void)zm_bucketDeleteWithName:(NSString *)bucketName;


@end

