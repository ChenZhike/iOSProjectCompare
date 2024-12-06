//
//  ViewController.h
//  QuChong
//
//  Created by 孙悟空 on 2024/12/6.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController

@property (weak, nonatomic) IBOutlet UIView *singleView;
@property (weak, nonatomic) IBOutlet UIView *compareView;
@property (weak, nonatomic) IBOutlet UITextView *singleResultTextView;
@property (weak, nonatomic) IBOutlet UITextView *compareResultTextView;
@property (weak, nonatomic) IBOutlet UIButton *project1Button;
@property (weak, nonatomic) IBOutlet UIButton *project2Button;

@end

