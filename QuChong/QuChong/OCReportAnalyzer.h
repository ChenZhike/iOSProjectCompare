#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface OCReportAnalyzer : NSObject

// 分析结果
@property (nonatomic, strong) NSMutableDictionary *duplicateMethodNames;
@property (nonatomic, strong) NSMutableDictionary *duplicatePropertyNames;
@property (nonatomic, strong) NSMutableDictionary *duplicateConstants;
@property (nonatomic, assign, readonly) CGFloat namingPatternSimilarity;      // 命名规律相似度
@property (nonatomic, assign, readonly) CGFloat projectSimilarity;            // 项目相似度
@property (nonatomic, assign, readonly) BOOL isSameDeveloper;                 // 是否同一个开发者
@property (nonatomic, assign, readonly) BOOL isTemplateApp;                   // 是否是马甲包关系
@property (nonatomic, strong) NSMutableArray<NSString *> *optimizationSuggestions;// 优化建议

// 主要方法
- (void)analyzeReports:(NSString *)reportPath1 
           reportPath2:(NSString *)reportPath2 
           completion:(void(^)(BOOL success, NSString *analysis))completion;

@end

NS_ASSUME_NONNULL_END 
