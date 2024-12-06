//
//  ViewController.m
//  QuChong
//
//  Created by 孙悟空 on 2024/12/6.
//

#import "ViewController.h"
#import "OCFileAnalyzer.h"
#import "OCReportAnalyzer.h"

@interface ViewController () <UIDocumentPickerDelegate>

@property (nonatomic, strong) NSString *project1Path;
@property (nonatomic, strong) NSString *project2Path;
@property (nonatomic, strong) OCFileAnalyzer *fileAnalyzer;
@property (nonatomic, strong) OCReportAnalyzer *reportAnalyzer;
@property (nonatomic, assign) NSInteger currentPickerMode;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.fileAnalyzer = [[OCFileAnalyzer alloc] init];
    self.reportAnalyzer = [[OCReportAnalyzer alloc] init];
}

#pragma mark - Actions

- (IBAction)modeChanged:(UISegmentedControl *)sender {
    self.singleView.hidden = sender.selectedSegmentIndex != 0;
    self.compareView.hidden = sender.selectedSegmentIndex != 1;
}

- (IBAction)selectProjectFolder:(id)sender {
    [self showFolderPickerForMode:0];
}

- (IBAction)selectProject1:(id)sender {
    [self showFolderPickerForMode:1];
}

- (IBAction)selectProject2:(id)sender {
    [self showFolderPickerForMode:2];
}

- (IBAction)startCompare:(id)sender {
    if (!self.project1Path || !self.project2Path) {
        [self showAlert:@"请先选择两个项目文件夹"];
        return;
    }
    
    // 先找出重复文件
    NSDictionary *duplicates = [self.fileAnalyzer findDuplicateFilesBetweenProject:self.project1Path 
                                                                      andProject:self.project2Path];
    
    // 先分析两个项目
    [self.fileAnalyzer analyzeProjectAtPath:self.project1Path completion:^(BOOL success, NSError * _Nullable error) {
        if (!success) {
            [self showAlert:@"分析项目1失败"];
            return;
        }
        
        [self.fileAnalyzer analyzeProjectAtPath:self.project2Path completion:^(BOOL success, NSError * _Nullable error) {
            if (!success) {
                [self showAlert:@"分析项目2失败"];
                return;
            }
            
            // 开始比较并生成报告
            [self.reportAnalyzer analyzeReports:
             [self.project1Path stringByAppendingPathComponent:@"源码分析报告.txt"]
                                   reportPath2:[self.project2Path stringByAppendingPathComponent:@"源码分析报告.txt"]
                                  completion:^(BOOL success, NSString *analysis) {
                if (success) {
                    // 在分析报告中添加重复文件信息
                    NSMutableString *fullAnalysis = [NSMutableString stringWithString:analysis];
                    if (duplicates.count > 0) {
                        [fullAnalysis appendString:@"\n文件重复分析\n"];
                        [fullAnalysis appendString:@"==============\n"];
                        [duplicates enumerateKeysAndObjectsUsingBlock:^(NSString *md5, NSArray *files, BOOL *stop) {
                            [fullAnalysis appendFormat:@"\nMD5: %@\n", md5];
                            [fullAnalysis appendString:@"重复文件:\n"];
                            for (NSString *file in files) {
                                [fullAnalysis appendFormat:@"- %@\n", file];
                            }
                        }];
                    }
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        self.compareResultTextView.text = fullAnalysis;
                    });
                } else {
                    [self showAlert:@"比较分析失败"];
                }
            }];
        }];
    }];
}

#pragma mark - Helper Methods

- (void)showFolderPickerForMode:(NSInteger)mode {
    self.currentPickerMode = mode;
    
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] 
                                            initWithDocumentTypes:@[@"public.folder"] 
                                            inMode:UIDocumentPickerModeOpen];
    picker.delegate = self;
    picker.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)showAlert:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示" 
                                                                 message:message 
                                                          preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" 
                                            style:UIAlertActionStyleDefault 
                                          handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - UIDocumentPickerDelegate

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *url = urls.firstObject;
    NSString *path = url.path;
    
    switch (self.currentPickerMode) {
        case 0: { // 单项目分析
            [self.fileAnalyzer analyzeProjectAtPath:path completion:^(BOOL success, NSError * _Nullable error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (success) {
                        NSString *reportPath = [path stringByAppendingPathComponent:@"源码分析报告.txt"];
                        NSError *readError;
                        NSString *report = [NSString stringWithContentsOfFile:reportPath 
                                                                  encoding:NSUTF8StringEncoding 
                                                                     error:&readError];
                        if (!readError) {
                            self.singleResultTextView.text = report;
                        } else {
                            [self showAlert:@"读取分析报告失败"];
                        }
                    } else {
                        [self showAlert:@"分析项目失败"];
                    }
                });
            }];
            break;
        }
        case 1: { // 项目1
            self.project1Path = path;
            [self.project1Button setTitle:url.lastPathComponent forState:UIControlStateNormal];
            break;
        }
        case 2: { // 项目2
            self.project2Path = path;
            [self.project2Button setTitle:url.lastPathComponent forState:UIControlStateNormal];
            break;
        }
    }
}

@end
