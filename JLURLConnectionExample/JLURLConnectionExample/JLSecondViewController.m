//
//  JLSecondViewController.m
//  JLURLConnectionExample
//
//  Created by Jonathan Lott on 5/17/14.
//  Copyright (c) 2014 A Lott Of Ideas. All rights reserved.
//

#import "JLSecondViewController.h"
#import <MediaPlayer/MediaPlayer.h>

@interface JLSecondViewController ()
@property (strong, nonatomic) IBOutlet UIButton *downloadButton;
@property (strong, nonatomic) IBOutlet UITextView *textView;
@property (strong, nonatomic) IBOutlet UILabel *progressLabel;
@property (strong, nonatomic) MPMoviePlayerViewController* moviePlayer;
@end

@implementation JLSecondViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    self.progressLabel.hidden = YES;
}


- (IBAction)download:(id)sender
{
    
    JLFile* file = [JLFile docuemntsFileWithFilePath:@"test.mov"];
    
    //http://download.blender.org/peach/bigbuckbunny_movies/BigBuckBunny_320x180.mp4
    NSURL* url = [NSURL URLWithString:@"http://download.blender.org/peach/bigbuckbunny_movies/BigBuckBunny_320x180.mp4"];
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url];
    __weak JLSecondViewController* weakSelf = self;
    __block BOOL tryProgressiveDownload = file.fileSize == file.expectedFileSize ? NO : YES;
    __block double tryPlaybackAfterPercentCompletion = 0.4;
    [JLURLConnection startConnectionWithRequest:request toFileAtPath:file.filePath progressBlock:^(JLURLConnection *urlConnection, JLURLConnectionState state, JLError *errorStatus) {
        
        double progress = urlConnection.progress;

        switch (state) {
            case JLURLConnectionState_Running:
            {
                self.progressLabel.hidden = NO;

                if(weakSelf.textView.text.length)
                    weakSelf.textView.text = @"This Example will download a movie to a file and display it here.  Press the Download button below.";
                
                weakSelf.textView.textColor = [UIColor blackColor];

                weakSelf.downloadButton.enabled = NO;
                weakSelf.progressLabel.text = [NSString stringWithFormat:@"Progress: %.0f%%", progress * 100.0];
                weakSelf.progressLabel.textColor = [UIColor redColor];
                
                if(tryProgressiveDownload && progress > tryPlaybackAfterPercentCompletion && file.fileSize && !self.moviePlayer)
                {
                    //playback file
                    self.moviePlayer = [[MPMoviePlayerViewController alloc] initWithContentURL:[NSURL fileURLWithPath:file.filePath]];
                    [self presentMoviePlayerViewControllerAnimated:self.moviePlayer];
                    [[NSNotificationCenter defaultCenter] addObserverForName:MPMoviePlayerPlaybackDidFinishNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
                            if(self.moviePlayer.moviePlayer.errorLog)
                            {
                                // progressive download failed
                                tryProgressiveDownload = NO;
                            }
                    }];
                }
                break;
            }
            case JLURLConnectionState_Finished:
            {
                weakSelf.downloadButton.enabled = YES;
                
                if(!urlConnection.errorStatus)
                {
                    weakSelf.progressLabel.text = [NSString stringWithFormat:@"Progress: %.0f%%", progress * 100.0];
                    weakSelf.progressLabel.textColor = [UIColor greenColor];
                    
                    if(!tryProgressiveDownload && file.fileSize && !self.moviePlayer)
                    {
                        //playback file
                        self.moviePlayer = [[MPMoviePlayerViewController alloc] initWithContentURL:[NSURL fileURLWithPath:file.filePath]];
                        [self presentMoviePlayerViewControllerAnimated:self.moviePlayer];
                    }
                }
                else
                {
                    weakSelf.textView.text = [NSString stringWithFormat:@"%@", urlConnection.errorStatus];
                    weakSelf.textView.textColor = [UIColor redColor];

                }
                break;
            }
            default:
                break;
        }
    }];
}
@end
