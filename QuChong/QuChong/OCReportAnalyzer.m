#import "OCReportAnalyzer.h"

@interface OCReportAnalyzer ()


@property (nonatomic, assign) CGFloat namingPatternSimilarity;
@property (nonatomic, assign) CGFloat projectSimilarity;
@property (nonatomic, assign) BOOL isSameDeveloper;
@property (nonatomic, assign) BOOL isTemplateApp;

@property (nonatomic, strong) NSDictionary *report1Data;
@property (nonatomic, strong) NSDictionary *report2Data;



@end

@implementation OCReportAnalyzer

- (instancetype)init {
    self = [super init];
    if (self) {
        _duplicateMethodNames = [NSMutableDictionary dictionary];
        _duplicatePropertyNames = [NSMutableDictionary dictionary];
        _duplicateConstants = [NSMutableDictionary dictionary];
        _optimizationSuggestions = [NSMutableArray array];
    }
    return self;
}

- (void)analyzeReports:(NSString *)reportPath1 
           reportPath2:(NSString *)reportPath2 
           completion:(void(^)(BOOL success, NSString *analysis))completion {
    // 读取报告容
    NSError *error;
    NSString *report1 = [NSString stringWithContentsOfFile:reportPath1 
                                                encoding:NSUTF8StringEncoding 
                                                   error:&error];
    if (error) {
        if (completion) {
            completion(NO, @"读取报告1失败");
        }
        return;
    }
    
    NSString *report2 = [NSString stringWithContentsOfFile:reportPath2 
                                                encoding:NSUTF8StringEncoding 
                                                   error:&error];
    if (error) {
        if (completion) {
            completion(NO, @"读取报告2失败");
        }
        return;
    }
    
    // 解析报告数据
    self.report1Data = [self parseReport:report1];
    self.report2Data = [self parseReport:report2];
    
    // 分析重复项
    [self analyzeDuplicates];
    
    // 分析命名规律
    [self analyzeNamingPatterns];
    
    // 生成优化建议
    [self generateOptimizationSuggestions];
    
    // 生成分析报告
    NSString *analysis = [self generateAnalysisReport];
    
    if (completion) {
        completion(YES, analysis);
    }
}

- (NSDictionary *)parseReport:(NSString *)report {
    NSMutableDictionary *data = [NSMutableDictionary dictionary];
    NSMutableDictionary *methods = [NSMutableDictionary dictionary];
    NSMutableDictionary *properties = [NSMutableDictionary dictionary];
    NSMutableDictionary *constants = [NSMutableDictionary dictionary];
    
    NSArray *lines = [report componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSString *currentSection = nil;
    
    for (NSString *line in lines) {
        if ([line containsString:@"方法名统计"]) {
            currentSection = @"methods";
            continue;
        } else if ([line containsString:@"属性名统计"]) {
            currentSection = @"properties";
            continue;
        } else if ([line containsString:@"常量统计"]) {
            currentSection = @"constants";
            continue;
        }
        
        if ([line containsString:@": 出现"]) {
            NSArray *parts = [line componentsSeparatedByString:@": 出现"];
            if (parts.count == 2) {
                NSString *name = [parts[0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                NSString *countStr = [[parts[1] stringByReplacingOccurrencesOfString:@"次" withString:@""] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                NSNumber *count = @([countStr integerValue]);
                
                if ([currentSection isEqualToString:@"methods"]) {
                    methods[name] = count;
                } else if ([currentSection isEqualToString:@"properties"]) {
                    properties[name] = count;
                }
            }
        } else if ([line containsString:@": 值="]) {
            NSArray *parts = [line componentsSeparatedByString:@": 值="];
            if (parts.count == 2) {
                NSString *name = [parts[0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                NSString *valueAndCount = parts[1];
                NSArray *valueParts = [valueAndCount componentsSeparatedByString:@", 出现"];
                if (valueParts.count == 2) {
                    constants[name] = @{
                        @"value": valueParts[0],
                        @"count": @([[valueParts[1] stringByReplacingOccurrencesOfString:@"次" withString:@""] integerValue])
                    };
                }
            }
        }
    }
    
    data[@"methods"] = methods;
    data[@"properties"] = properties;
    data[@"constants"] = constants;
    
    return data;
}

- (void)analyzeDuplicates {
    // 分析方法名重复
    NSDictionary *methods1 = self.report1Data[@"methods"];
    NSDictionary *methods2 = self.report2Data[@"methods"];
    
    [methods1 enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSNumber *obj1, BOOL *stop) {
        NSNumber *obj2 = methods2[key];
        if (obj2) {
            self.duplicateMethodNames[key] = @{@"project1": obj1, @"project2": obj2};
        }
    }];
    
    // 分析属性名重复
    NSDictionary *properties1 = self.report1Data[@"properties"];
    NSDictionary *properties2 = self.report2Data[@"properties"];
    
    [properties1 enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSNumber *obj1, BOOL *stop) {
        NSNumber *obj2 = properties2[key];
        if (obj2) {
            self.duplicatePropertyNames[key] = @{@"project1": obj1, @"project2": obj2};
        }
    }];
    
    // 分析常量重复
    NSDictionary *constants1 = self.report1Data[@"constants"];
    NSDictionary *constants2 = self.report2Data[@"constants"];
    
    [constants1 enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSDictionary *obj1, BOOL *stop) {
        NSDictionary *obj2 = constants2[key];
        if (obj2) {
            self.duplicateConstants[key] = @{@"project1": obj1, @"project2": obj2};
        }
    }];
}

- (void)analyzeNamingPatterns {
    // 分析命名规律
    NSArray *patterns1 = [self extractNamingPatterns:self.report1Data];
    NSArray *patterns2 = [self extractNamingPatterns:self.report2Data];
    
    // 计算命名规律相似度
    self.namingPatternSimilarity = [self calculatePatternSimilarity:patterns1 patterns2:patterns2];
    
    // 计算项目相似度
    self.projectSimilarity = [self calculateProjectSimilarity];
    
    // 判断是否同一个开发者
    self.isSameDeveloper = self.namingPatternSimilarity > 0.7 && self.projectSimilarity > 0.5;
    
    // 判断是否是马甲包
    self.isTemplateApp = self.projectSimilarity > 0.8;
}

- (NSArray *)extractNamingPatterns:(NSDictionary *)reportData {
    NSMutableArray *patterns = [NSMutableArray array];
    
    // 分析方法名前缀和后缀模式
    [self analyzeNamingPattern:reportData[@"methods"] patterns:patterns type:@"method"];
    
    // 分析属性名前缀和后缀模式
    [self analyzeNamingPattern:reportData[@"properties"] patterns:patterns type:@"property"];
    
    return patterns;
}

- (void)analyzeNamingPattern:(NSDictionary *)names patterns:(NSMutableArray *)patterns type:(NSString *)type {
    NSMutableDictionary *prefixCount = [NSMutableDictionary dictionary];
    NSMutableDictionary *suffixCount = [NSMutableDictionary dictionary];
    
    [names enumerateKeysAndObjectsUsingBlock:^(NSString *name, id obj, BOOL *stop) {
        // 分析前缀（取前2-3个字符）
        if (name.length >= 3) {
            NSString *prefix = [name substringToIndex:3];
            prefixCount[prefix] = @([prefixCount[prefix] integerValue] + 1);
        }
        
        // 分析后缀（取后2-3个字符）
        if (name.length >= 3) {
            NSString *suffix = [name substringFromIndex:name.length - 3];
            suffixCount[suffix] = @([suffixCount[suffix] integerValue] + 1);
        }
    }];
    
    [patterns addObject:@{@"type": type, @"prefixes": prefixCount, @"suffixes": suffixCount}];
}

- (CGFloat)calculatePatternSimilarity:(NSArray *)patterns1 patterns2:(NSArray *)patterns2 {
    // 简单实现：计算相同前缀和后缀的比例
    NSMutableSet *commonPatterns = [NSMutableSet set];
    NSMutableSet *allPatterns = [NSMutableSet set];
    
    for (NSDictionary *pattern1 in patterns1) {
        NSDictionary *prefixes1 = pattern1[@"prefixes"];
        [allPatterns addObjectsFromArray:prefixes1.allKeys];
        
        for (NSDictionary *pattern2 in patterns2) {
            NSDictionary *prefixes2 = pattern2[@"prefixes"];
            [allPatterns addObjectsFromArray:prefixes2.allKeys];
            
            // 创建两个集合的副本
            NSMutableSet *set1 = [NSMutableSet setWithArray:prefixes1.allKeys];
            NSMutableSet *set2 = [NSMutableSet setWithArray:prefixes2.allKeys];
            
            // 计算交集
            [set1 intersectSet:set2];
            [commonPatterns addObjectsFromArray:set1.allObjects];
        }
    }
    
    return (CGFloat)commonPatterns.count / allPatterns.count;
}

- (CGFloat)calculateProjectSimilarity {
    // 计算重复项占总项的比例
    NSInteger totalMethods1 = [self.report1Data[@"methods"] count];
    NSInteger totalMethods2 = [self.report2Data[@"methods"] count];
    NSInteger duplicateMethods = self.duplicateMethodNames.count;
    
    NSInteger totalProperties1 = [self.report1Data[@"properties"] count];
    NSInteger totalProperties2 = [self.report2Data[@"properties"] count];
    NSInteger duplicateProperties = self.duplicatePropertyNames.count;
    
    CGFloat methodSimilarity = (CGFloat)duplicateMethods / ((totalMethods1 + totalMethods2) / 2.0);
    CGFloat propertySimilarity = (CGFloat)duplicateProperties / ((totalProperties1 + totalProperties2) / 2.0);
    
    return (methodSimilarity + propertySimilarity) / 2.0;
}

- (void)generateOptimizationSuggestions {
    [self.optimizationSuggestions removeAllObjects];
    
    // 1. 分析重复方法名
    [self analyzeDuplicateMethodNames];
    
    // 2. 分析重复属性名
    [self analyzeDuplicatePropertyNames];
    
    // 3. 分析重复常量
    [self analyzeDuplicateConstants];
    
    // 4. 分析命名模式
    [self analyzeNamingPatternOptimization];
}

- (void)analyzeDuplicateMethodNames {
    if (self.duplicateMethodNames.count > 0) {
        // 找出出现频率最高的方法名
        NSArray *sortedMethods = [self.duplicateMethodNames keysSortedByValueUsingComparator:^NSComparisonResult(NSDictionary *obj1, NSDictionary *obj2) {
            NSInteger count1 = [obj1[@"project1"] integerValue] + [obj1[@"project2"] integerValue];
            NSInteger count2 = [obj2[@"project1"] integerValue] + [obj2[@"project2"] integerValue];
            return [@(count2) compare:@(count1)];
        }];
        
        for (NSString *methodName in [sortedMethods subarrayWithRange:NSMakeRange(0, MIN(3, sortedMethods.count))]) {
            [self.optimizationSuggestions addObject:[NSString stringWithFormat:@"建议修改重复度较高的方法名'%@'，可以添加业务相关前缀或更具体的描述", methodName]];
        }
    }
}

- (void)analyzeDuplicatePropertyNames {
    if (self.duplicatePropertyNames.count > 0) {
        // 找出出现频率最高的属性名
        NSArray *sortedProperties = [self.duplicatePropertyNames keysSortedByValueUsingComparator:^NSComparisonResult(NSDictionary *obj1, NSDictionary *obj2) {
            NSInteger count1 = [obj1[@"project1"] integerValue] + [obj1[@"project2"] integerValue];
            NSInteger count2 = [obj2[@"project1"] integerValue] + [obj2[@"project2"] integerValue];
            return [@(count2) compare:@(count1)];
        }];
        
        for (NSString *propertyName in [sortedProperties subarrayWithRange:NSMakeRange(0, MIN(3, sortedProperties.count))]) {
            [self.optimizationSuggestions addObject:[NSString stringWithFormat:@"建议修改重复的属性名'%@'，可以使用更具体的业务描述或添加模块前缀", propertyName]];
        }
    }
}

- (void)analyzeDuplicateConstants {
    if (self.duplicateConstants.count > 0) {
        for (NSString *constantName in self.duplicateConstants) {
            NSDictionary *project1Data = self.duplicateConstants[constantName][@"project1"];
            NSDictionary *project2Data = self.duplicateConstants[constantName][@"project2"];
            
            if (![project1Data[@"value"] isEqual:project2Data[@"value"]]) {
                [self.optimizationSuggestions addObject:[NSString stringWithFormat:@"常量'%@'在两个项目中值不同，建议使用不同的常量名以避免混淆", constantName]];
            }
        }
    }
}

- (void)analyzeNamingPatternOptimization {
    if (self.namingPatternSimilarity > 0.7) {
        [self.optimizationSuggestions addObject:@"建议对命名模式进行以下优化："];
        [self.optimizationSuggestions addObject:@"1. 为不同业务模块设计独特的命名前缀"];
        [self.optimizationSuggestions addObject:@"2. 避免使用过于通用的命名（如data、info、manager等）"];
        [self.optimizationSuggestions addObject:@"3. 在方法名中增加具体的业务场景描述"];
    }
    
    if (self.projectSimilarity > 0.8) {
        [self.optimizationSuggestions addObject:@"项目相似度过高，建议："];
        [self.optimizationSuggestions addObject:@"1. 重构项目结构，突出各自的业务特点"];
        [self.optimizationSuggestions addObject:@"2. 将共用代码抽取为独立的SDK或组件"];
        [self.optimizationSuggestions addObject:@"3. 为每个项目设计独特的架构模式"];
    }
}

- (NSString *)generateAnalysisReport {
    NSMutableString *report = [NSMutableString string];
    
    [report appendString:@"\n项目对比分析报告\n"];
    [report appendString:@"==============\n\n"];
    
    // 重复项统计
    [report appendFormat:@"重复方法数量: %lu\n", (unsigned long)self.duplicateMethodNames.count];
    [report appendFormat:@"重复属性数量: %lu\n", (unsigned long)self.duplicatePropertyNames.count];
    [report appendFormat:@"重复常量数量: %lu\n\n", (unsigned long)self.duplicateConstants.count];
    
    // 相似度分析
    [report appendFormat:@"命名规律相似度: %.2f%%\n", self.namingPatternSimilarity * 100];
    [report appendFormat:@"项目整体相似度: %.2f%%\n\n", self.projectSimilarity * 100];
    
    // 结论
    [report appendString:@"分析结论：\n"];
    [report appendFormat:@"1. 是否同一个开发者: %@\n", self.isSameDeveloper ? @"是" : @"否"];
    [report appendFormat:@"2. 是否存在马甲包关系: %@\n\n", self.isTemplateApp ? @"是" : @"否"];
    
    // 生成优化建议
    [self generateOptimizationSuggestions];
    
    // 添加优化建议到报告
    if (self.optimizationSuggestions.count > 0) {
        [report appendString:@"优化建议：\n"];
        [report appendString:@"==============\n"];
        for (NSString *suggestion in self.optimizationSuggestions) {
            [report appendFormat:@"%@\n", suggestion];
        }
    }
    
    return report;
}

@end 
