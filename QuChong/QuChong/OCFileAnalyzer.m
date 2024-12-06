#import "OCFileAnalyzer.h"

@interface OCFileAnalyzer ()



@end

@implementation OCFileAnalyzer

- (instancetype)init {
    self = [super init];
    if (self) {
        _fangFaNames = [NSMutableArray array];
        _shuXingNames = [NSMutableArray array];
        _changLiangs = [NSMutableDictionary dictionary];
        _fangFaCount = [NSMutableDictionary dictionary];
        _shuXingCount = [NSMutableDictionary dictionary];
        _changLiangCount = [NSMutableDictionary dictionary];
        _prefixStats = [NSMutableDictionary dictionary];
        _suffixStats = [NSMutableDictionary dictionary];
        _totalPrefixCount = 0;
        _totalSuffixCount = 0;
        _totalItemCount = 0;
        _fileContentMD5s = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)analyzeProjectAtPath:(NSString *)projectPath 
                 completion:(void(^)(BOOL success, NSError * _Nullable error))completion {
    [self.fangFaCount removeAllObjects];
    [self.shuXingCount removeAllObjects];
    [self.changLiangCount removeAllObjects];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error;
    
    NSArray *contents = [self getAllFilesAtPath:projectPath];
    if (!contents) {
        if (completion) {
            completion(NO, error);
        }
        return;
    }
    
    for (NSString *path in contents) {
        if ([path.pathExtension isEqualToString:@"h"] || 
            [path.pathExtension isEqualToString:@"m"]) {
            [self analyzeFile:path];
        }
    }
    
    NSString *reportPath = [projectPath stringByAppendingPathComponent:@"源码分析报告.txt"];
    [self generateReportToPath:reportPath];
    
    if (completion) {
        completion(YES, nil);
    }
}

- (NSArray *)getAllFilesAtPath:(NSString *)directoryPath {
    NSMutableArray *allFiles = [NSMutableArray array];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error;
    
    NSArray *contents = [fileManager contentsOfDirectoryAtPath:directoryPath error:&error];
    if (error) {
        NSLog(@"读取目录失败：%@", error);
        return nil;
    }
    
    for (NSString *path in contents) {
        NSString *fullPath = [directoryPath stringByAppendingPathComponent:path];
        BOOL isDirectory = NO;
        
        if ([fileManager fileExistsAtPath:fullPath isDirectory:&isDirectory]) {
            if (isDirectory) {
                NSArray *subFiles = [self getAllFilesAtPath:fullPath];
                if (subFiles) {
                    [allFiles addObjectsFromArray:subFiles];
                }
            } else {
                [allFiles addObject:fullPath];
            }
        }
    }
    
    return allFiles;
}

- (void)analyzeFile:(NSString *)filePath {
    NSError *error;
    NSString *content = [NSString stringWithContentsOfFile:filePath 
                                                encoding:NSUTF8StringEncoding 
                                                   error:&error];
    if (error) {
        NSLog(@"读取文件失败：%@", error);
        return;
    }
    
    // 计算文件MD5
    NSString *cleanContent = [self removeCommentsFromContent:content];
    NSString *md5 = [self md5ForContent:cleanContent];
    self.fileContentMD5s[filePath.lastPathComponent] = md5;
    
    NSRegularExpression *methodRegex = [NSRegularExpression regularExpressionWithPattern:@"[-+]\\s*\\([^)]+\\)\\s*([a-zA-Z][a-zA-Z0-9]*:?)" 
                                                                               options:0 
                                                                                 error:nil];
    
    NSRegularExpression *propertyRegex = [NSRegularExpression regularExpressionWithPattern:@"@property\\s*\\([^)]+\\)\\s*[a-zA-Z][a-zA-Z0-9]*\\s*\\*?\\s*([a-zA-Z][a-zA-Z0-9]*)" 
                                                                                  options:0 
                                                                                    error:nil];
    
    NSRegularExpression *constantRegex = [NSRegularExpression regularExpressionWithPattern:@"static\\s+const\\s+[a-zA-Z][a-zA-Z0-9]*\\s+([a-zA-Z][a-zA-Z0-9]*)\\s*=\\s*([^;]+);" 
                                                                                  options:0 
                                                                                    error:nil];
    
    [methodRegex enumerateMatchesInString:content 
                                 options:0 
                                   range:NSMakeRange(0, content.length) 
                              usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
        NSString *methodName = [content substringWithRange:[result rangeAtIndex:1]];
        [self.fangFaNames addObject:methodName];
        NSNumber *count = self.fangFaCount[methodName] ?: @0;
        self.fangFaCount[methodName] = @(count.integerValue + 1);
        [self analyzePrefixForName:methodName];
        [self analyzeSuffixForName:methodName];
        self.totalItemCount++;
    }];
    
    [propertyRegex enumerateMatchesInString:content 
                                   options:0 
                                     range:NSMakeRange(0, content.length) 
                                usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
        NSString *propertyName = [content substringWithRange:[result rangeAtIndex:1]];
        [self.shuXingNames addObject:propertyName];
        NSNumber *count = self.shuXingCount[propertyName] ?: @0;
        self.shuXingCount[propertyName] = @(count.integerValue + 1);
        [self analyzePrefixForName:propertyName];
        [self analyzeSuffixForName:propertyName];
        self.totalItemCount++;
    }];
    
    [constantRegex enumerateMatchesInString:content 
                                   options:0 
                                     range:NSMakeRange(0, content.length) 
                                usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
        NSString *constantName = [content substringWithRange:[result rangeAtIndex:1]];
        NSString *constantValue = [content substringWithRange:[result rangeAtIndex:2]];
        self.changLiangs[constantName] = constantValue;
        NSNumber *count = self.changLiangCount[constantName] ?: @0;
        self.changLiangCount[constantName] = @(count.integerValue + 1);
        [self analyzePrefixForName:constantName];
        [self analyzeSuffixForName:constantName];
        self.totalItemCount++;
    }];
}

- (void)generateReportToPath:(NSString *)reportPath {
    NSMutableString *report = [NSMutableString string];
    
    [report appendString:@"iOS源码分析报告\n"];
    [report appendString:@"=================\n\n"];
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    [report appendFormat:@"生成时间：%@\n\n", [formatter stringFromDate:[NSDate date]]];
    
    [report appendString:@"方法名统计\n"];
    [report appendString:@"-----------------\n"];
    [self appendStatistics:self.fangFaCount toReport:report];
    
    [report appendString:@"\n属性名统计\n"];
    [report appendString:@"-----------------\n"];
    [self appendStatistics:self.shuXingCount toReport:report];
    
    [report appendString:@"\n常量统计\n"];
    [report appendString:@"-----------------\n"];
    [self appendStatistics:self.changLiangCount toReport:report withValues:self.changLiangs];
    
    [report appendString:@"\n命名规范分析\n"];
    [report appendString:@"-----------------\n"];
    [report appendFormat:@"总分析项目数: %ld\n", (long)self.totalItemCount];
    [report appendFormat:@"带前缀项目数: %ld (%.1f%%)\n", 
     (long)self.totalPrefixCount, 
     (float)self.totalPrefixCount * 100 / MAX(1, self.totalItemCount)];
    [report appendFormat:@"带后缀项目数: %ld (%.1f%%)\n\n", 
     (long)self.totalSuffixCount, 
     (float)self.totalSuffixCount * 100 / MAX(1, self.totalItemCount)];
    
    [report appendString:@"前缀使用统计:\n"];
    NSArray *sortedPrefixes = [self.prefixStats keysSortedByValueUsingComparator:^NSComparisonResult(NSNumber *obj1, NSNumber *obj2) {
        return [obj2 compare:obj1];
    }];
    for (NSString *prefix in sortedPrefixes) {
        [report appendFormat:@"%@: 使用 %@ 次\n", prefix, self.prefixStats[prefix]];
    }
    [report appendString:@"\n"];
    
    [report appendString:@"后缀使用统计:\n"];
    NSArray *sortedSuffixes = [self.suffixStats keysSortedByValueUsingComparator:^NSComparisonResult(NSNumber *obj1, NSNumber *obj2) {
        return [obj2 compare:obj1];
    }];
    for (NSString *suffix in sortedSuffixes) {
        [report appendFormat:@"%@: 使用 %@ 次\n", suffix, self.suffixStats[suffix]];
    }
    
    NSError *error;
    [report writeToFile:reportPath 
             atomically:YES 
               encoding:NSUTF8StringEncoding 
                  error:&error];
    
    if (error) {
        NSLog(@"写入报告失败：%@", error);
    } else {
        NSLog(@"报告已生成：%@", reportPath);
    }
}

- (void)appendStatistics:(NSDictionary<NSString *, NSNumber *> *)statistics 
                toReport:(NSMutableString *)report {
    NSArray *sortedKeys = [statistics keysSortedByValueUsingComparator:^NSComparisonResult(NSNumber *obj1, NSNumber *obj2) {
        return [obj2 compare:obj1];
    }];
    
    for (NSString *key in sortedKeys) {
        [report appendFormat:@"%@: 出现 %@ 次\n", key, statistics[key]];
    }
}

- (void)appendStatistics:(NSDictionary<NSString *, NSNumber *> *)statistics 
                toReport:(NSMutableString *)report 
             withValues:(NSDictionary<NSString *, id> *)values {
    NSArray *sortedKeys = [statistics keysSortedByValueUsingComparator:^NSComparisonResult(NSNumber *obj1, NSNumber *obj2) {
        return [obj2 compare:obj1];
    }];
    
    for (NSString *key in sortedKeys) {
        [report appendFormat:@"%@: =%@, 出现 %@ 次\n", key, values[key], statistics[key]];
    }
}

- (void)analyzePrefixForName:(NSString *)name {
    NSRegularExpression *prefixRegex = [NSRegularExpression regularExpressionWithPattern:@"^[a-zA-Z]+_" 
                                                                               options:0 
                                                                                 error:nil];
    NSTextCheckingResult *match = [prefixRegex firstMatchInString:name 
                                                        options:0 
                                                          range:NSMakeRange(0, name.length)];
    if (match) {
        NSString *prefix = [name substringWithRange:match.range];
        NSNumber *count = self.prefixStats[prefix] ?: @0;
        self.prefixStats[prefix] = @(count.integerValue + 1);
        self.totalPrefixCount++;
    }
}

- (void)analyzeSuffixForName:(NSString *)name {
    NSRegularExpression *suffixRegex = [NSRegularExpression regularExpressionWithPattern:@"_[a-zA-Z0-9]+$" 
                                                                               options:0 
                                                                                 error:nil];
    NSTextCheckingResult *match = [suffixRegex firstMatchInString:name 
                                                        options:0 
                                                          range:NSMakeRange(0, name.length)];
    if (match) {
        NSString *suffix = [name substringWithRange:match.range];
        NSNumber *count = self.suffixStats[suffix] ?: @0;
        self.suffixStats[suffix] = @(count.integerValue + 1);
        self.totalSuffixCount++;
    }
}

- (NSString *)md5ForContent:(NSString *)content {
    // 简单的哈希算法
    NSUInteger hash = 0;
    for (NSInteger i = 0; i < content.length; i++) {
        hash = hash * 31 + [content characterAtIndex:i];
    }
    return [NSString stringWithFormat:@"%lx", (unsigned long)hash];
}

- (NSString *)removeCommentsFromContent:(NSString *)content {
    // 移除单行注释 //
    NSRegularExpression *singleLineRegex = [NSRegularExpression regularExpressionWithPattern:@"//[^\n]*" 
                                                                                   options:0 
                                                                                     error:nil];
    content = [singleLineRegex stringByReplacingMatchesInString:content 
                                                      options:0 
                                                        range:NSMakeRange(0, content.length) 
                                                 withTemplate:@""];
    
    // 移除多行注释 /* */
    NSRegularExpression *multiLineRegex = [NSRegularExpression regularExpressionWithPattern:@"/\\*[^*]*\\*+(?:[^/*][^*]*\\*+)*/" 
                                                                                  options:NSRegularExpressionDotMatchesLineSeparators 
                                                                                    error:nil];
    content = [multiLineRegex stringByReplacingMatchesInString:content 
                                                     options:0 
                                                       range:NSMakeRange(0, content.length) 
                                                withTemplate:@""];
    
    // 移除空行和空格
    content = [[content componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] 
              componentsJoinedByString:@""];
    
    return content;
}

- (NSDictionary *)findDuplicateFilesBetweenProject:(NSString *)projectPath1 
                                       andProject:(NSString *)projectPath2 {
    // 清空之前的MD5记录
    [self.fileContentMD5s removeAllObjects];
    
    // 分析第一个项目
    NSMutableDictionary *project1MD5s = [NSMutableDictionary dictionary];
    NSArray *files1 = [self getAllFilesAtPath:projectPath1];
    for (NSString *filePath in files1) {
        if ([filePath.pathExtension isEqualToString:@"h"] || 
            [filePath.pathExtension isEqualToString:@"m"]) {
            NSError *error;
            NSString *content = [NSString stringWithContentsOfFile:filePath 
                                                       encoding:NSUTF8StringEncoding 
                                                          error:&error];
            if (!error) {
                NSString *cleanContent = [self removeCommentsFromContent:content];
                NSString *md5 = [self md5ForContent:cleanContent];
                project1MD5s[filePath.lastPathComponent] = md5;
            }
        }
    }
    
    // 分析第二个项目并比较
    NSMutableDictionary *duplicateFiles = [NSMutableDictionary dictionary];
    NSArray *files2 = [self getAllFilesAtPath:projectPath2];
    for (NSString *filePath in files2) {
        if ([filePath.pathExtension isEqualToString:@"h"] || 
            [filePath.pathExtension isEqualToString:@"m"]) {
            NSError *error;
            NSString *content = [NSString stringWithContentsOfFile:filePath 
                                                       encoding:NSUTF8StringEncoding 
                                                          error:&error];
            if (!error) {
                NSString *cleanContent = [self removeCommentsFromContent:content];
                NSString *md5 = [self md5ForContent:cleanContent];
                
                // 查找相同MD5的文件
                [project1MD5s enumerateKeysAndObjectsUsingBlock:^(NSString *fileName1, NSString *md51, BOOL *stop) {
                    if ([md51 isEqualToString:md5]) {
                        // 找到重复文件
                        NSMutableArray *files = duplicateFiles[md5] ?: [NSMutableArray array];
                        if (![files containsObject:fileName1]) {
                            [files addObject:fileName1];
                        }
                        if (![files containsObject:filePath.lastPathComponent]) {
                            [files addObject:filePath.lastPathComponent];
                        }
                        duplicateFiles[md5] = files;
                    }
                }];
            }
        }
    }
    
    return duplicateFiles;
}

- (void)generateReportToPath:(NSString *)reportPath withDuplicates:(NSDictionary *)duplicates {
    NSMutableString *report = [NSMutableString string];
    
    [report appendString:@"iOS源码分析报告\n"];
    [report appendString:@"=================\n\n"];
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    [report appendFormat:@"生成时间：%@\n\n", [formatter stringFromDate:[NSDate date]]];
    
    [report appendString:@"方法名统计\n"];
    [report appendString:@"-----------------\n"];
    [self appendStatistics:self.fangFaCount toReport:report];
    
    [report appendString:@"\n属性名统计\n"];
    [report appendString:@"-----------------\n"];
    [self appendStatistics:self.shuXingCount toReport:report];
    
    [report appendString:@"\n常量统计\n"];
    [report appendString:@"-----------------\n"];
    [self appendStatistics:self.changLiangCount toReport:report withValues:self.changLiangs];
    
    [report appendString:@"\n命名规范分析\n"];
    [report appendString:@"-----------------\n"];
    [report appendFormat:@"总分析项目数: %ld\n", (long)self.totalItemCount];
    [report appendFormat:@"带前缀项目数: %ld (%.1f%%)\n", 
     (long)self.totalPrefixCount, 
     (float)self.totalPrefixCount * 100 / MAX(1, self.totalItemCount)];
    [report appendFormat:@"带后缀项目数: %ld (%.1f%%)\n\n", 
     (long)self.totalSuffixCount, 
     (float)self.totalSuffixCount * 100 / MAX(1, self.totalItemCount)];
    
    [report appendString:@"前缀使用统计:\n"];
    NSArray *sortedPrefixes = [self.prefixStats keysSortedByValueUsingComparator:^NSComparisonResult(NSNumber *obj1, NSNumber *obj2) {
        return [obj2 compare:obj1];
    }];
    for (NSString *prefix in sortedPrefixes) {
        [report appendFormat:@"%@: 使用 %@ 次\n", prefix, self.prefixStats[prefix]];
    }
    [report appendString:@"\n"];
    
    [report appendString:@"后缀使用统计:\n"];
    NSArray *sortedSuffixes = [self.suffixStats keysSortedByValueUsingComparator:^NSComparisonResult(NSNumber *obj1, NSNumber *obj2) {
        return [obj2 compare:obj1];
    }];
    for (NSString *suffix in sortedSuffixes) {
        [report appendFormat:@"%@: 使用 %@ 次\n", suffix, self.suffixStats[suffix]];
    }
    
    if (duplicates.count > 0) {
        [report appendString:@"\n文件重复分析\n"];
        [report appendString:@"-----------------\n"];
        [report appendFormat:@"发现 %lu 组重复文件：\n\n", (unsigned long)duplicates.count];
        
        [duplicates enumerateKeysAndObjectsUsingBlock:^(NSString *md5, NSArray *files, BOOL *stop) {
            [report appendFormat:@"MD5值: %@\n", md5];
            [report appendString:@"重复文件:\n"];
            for (NSString *fileName in files) {
                [report appendFormat:@"- %@\n", fileName];
            }
            [report appendString:@"\n"];
        }];
    }
    
    NSError *error;
    [report writeToFile:reportPath 
             atomically:YES 
               encoding:NSUTF8StringEncoding 
                  error:&error];
    
    if (error) {
        NSLog(@"写入报告失败：%@", error);
    } else {
        NSLog(@"报告已生成：%@", reportPath);
    }
}

@end 
