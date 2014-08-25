//
//  JLFirstViewController.m
//  JLURLConnectionExample
//
//  Created by Jonathan Lott on 5/17/14.
//  Copyright (c) 2014 A Lott Of Ideas. All rights reserved.
//

#import "JLFirstViewController.h"

@interface JLFirstViewController ()
@property (strong, nonatomic) IBOutlet UIButton *downloadButton;
@property (strong, nonatomic) IBOutlet UITextView *textView;
@property (strong, nonatomic) IBOutlet UILabel *progressLabel;

@end

@implementation JLFirstViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.progressLabel.hidden = YES;
    
}

- (IBAction)download:(id)sender
{
    //http://mouseshouses.blogspot.com/feeds/posts/default?alt=json
    NSURL* url = [NSURL URLWithString:@"http://mouseshouses.blogspot.com/feeds/posts/default?alt=json"];
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url];
    __weak JLFirstViewController* weakSelf = self;

    [JLURLConnection startConnectionWithRequest:request
                                  progressBlock:^(JLURLConnection *urlConnection, JLURLConnectionState state, JLError *errorStatus) {
                                      double progress = urlConnection.progress;

                                      switch (state) {
                                          case JLURLConnectionState_Running:
                                          {
                                              
                                              self.progressLabel.hidden = NO;

                                              if(weakSelf.textView.text.length)
                                                  weakSelf.textView.text = @"";
                                              
                                              
                                              weakSelf.downloadButton.enabled = NO;
                                              weakSelf.progressLabel.text = [NSString stringWithFormat:@"Progress: %.0f%%", progress * 100.0];
                                              weakSelf.progressLabel.textColor = [UIColor redColor];

                                              break;
                                          }
                                          case JLURLConnectionState_Finished:
                                          {
                                              weakSelf.textView.text = [NSString stringWithFormat:@"%@", urlConnection.data.jsonDictionaryValue.jsonStringValue];
                                              
                                              weakSelf.downloadButton.enabled = YES;
                                              weakSelf.progressLabel.text = [NSString stringWithFormat:@"Progress: %.0f%%", progress * 100.0];
                                              weakSelf.progressLabel.textColor = [UIColor greenColor];
                                              break;
                                          }
                                          default:
                                              break;
                                      }
                                  }];
}
@end
