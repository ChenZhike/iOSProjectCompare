#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface OCFileAnalyzer : NSObject

// 分析结果的数据结构
//@property (nonatomic, strong, readonly) NSArray<NSString *> *methodNames;
//@property (nonatomic, strong, readonly) NSArray<NSString *> *propertyNames;
//@property (nonatomic, strong, readonly) NSDictionary<NSString *, id> *constants;
@property (nonatomic, strong) NSMutableArray<NSString *> *fangFaNames;
@property (nonatomic, strong) NSMutableArray<NSString *> *shuXingNames;
@property (nonatomic, strong) NSMutableDictionary<NSString *, id> *changLiangs;
// 添加新的属性来存储统计数据
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *fangFaCount;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *shuXingCount;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *changLiangCount;
// 添加新的属性
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *prefixStats;  // 前缀统计
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *suffixStats;  // 后缀统计
@property (nonatomic, assign) NSInteger totalPrefixCount;  // 带前缀的总数
@property (nonatomic, assign) NSInteger totalSuffixCount;  // 带后缀的总数
@property (nonatomic, assign) NSInteger totalItemCount;    // 总项目数
// 添加新的属性
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *fileContentMD5s;  // 文件名->MD5值映射

// 主要方法
- (void)analyzeProjectAtPath:(NSString *)projectPath 
                 completion:(void(^)(BOOL success, NSError * _Nullable error))completion;
// 添加生成报告的方法
- (void)generateReportToPath:(NSString *)reportPath;
// 添加新的方法
- (NSDictionary *)findDuplicateFilesBetweenProject:(NSString *)projectPath1 
                                       andProject:(NSString *)projectPath2;

@end

NS_ASSUME_NONNULL_END 
