//
//  ViewController.m
//  ESCFFmpegRecordMp4Demo
//
//  Created by xiang on 2018/10/24.
//  Copyright © 2018 xiang. All rights reserved.
//

#import "ViewController.h"
#import "ESCFFmepgRecordMp4Tool/ESCFFmpegRecordMp4Tool.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self recordTestH265ToMp4WithH265FileName:@"test_1_640_360.h265"];
    [self recordTestH265ToMp4WithH265FileName:@"test_2_640_360.h265"];
    
    [self recordTestH264ToMp4WithH265FileName:@"video_480_854.h264" width:480 height:720];
    [self recordTestH264ToMp4WithH265FileName:@"video_1280_720.h264" width:1280 height:720];
    [self recordTestH264ToMp4WithH265FileName:@"video_1280_720_2.h264" width:1280 height:720];
    NSLog(@"%@",NSHomeDirectory());
}

- (void)recordTestH265ToMp4WithH265FileName:(NSString *)h265FileName {
    NSString *h265FilePath = [[NSBundle mainBundle] pathForResource:h265FileName ofType:nil];
    
    NSString *mp4FilePath = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).lastObject;
    NSString *mp4FileName = [h265FilePath lastPathComponent];
    mp4FileName = [mp4FileName stringByReplacingOccurrencesOfString:@"h265" withString:@"mp4"];
    mp4FilePath = [NSString stringWithFormat:@"%@/%@",mp4FilePath,mp4FileName];
    
    [ESCFFmpegRecordMp4Tool H265RecordToMP4WithH265FilePath:h265FilePath mp4FilePath:mp4FilePath videoWidth:640 videoHeight:360 videoFrameRate:25];
}

- (void)recordTestH264ToMp4WithH265FileName:(NSString *)h264FileName width:(int)width height:(int)height{
    NSString *h264FilePath = [[NSBundle mainBundle] pathForResource:h264FileName ofType:nil];
    
    NSString *mp4FilePath = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).lastObject;
    NSString *mp4FileName = [h264FilePath lastPathComponent];
    mp4FileName = [mp4FileName stringByReplacingOccurrencesOfString:@"h264" withString:@"mp4"];
    mp4FilePath = [NSString stringWithFormat:@"%@/%@",mp4FilePath,mp4FileName];
    
    NSString *aacPath = [[NSBundle mainBundle] pathForResource:@"8000_1_16_1.aac" ofType:nil];
    
    [ESCFFmpegRecordMp4Tool H264RecordToMP4WithH264FilePath:h264FilePath aacFilePath:aacPath mp4FilePath:mp4FilePath videoWidth:width videoHeight:height videoFrameRate:25];
}


@end
