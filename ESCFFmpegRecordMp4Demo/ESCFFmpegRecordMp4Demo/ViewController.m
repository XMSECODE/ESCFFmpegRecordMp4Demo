//
//  ViewController.m
//  ESCFFmpegRecordMp4Demo
//
//  Created by xiang on 2018/10/24.
//  Copyright © 2018 xiang. All rights reserved.
//

#import "ViewController.h"
#import "ESCFFmepgRecordMp4Tool/ESCFFmpegRecordMp4Tool.h"
#include "mux.h"
@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
//    [self recordTestH265ToMp4WithH265FileName:@"test_1_640_360.h265"];
//    [self recordTestH265ToMp4WithH265FileName:@"test_2_640_360.h265"];
    
    [self recordTestH264ToMp4WithH265FileName:@"video_480_854.h264" width:480 height:854];
    [self recordTestH264ToMp4WithH265FileName:@"video_1280_720.h264" width:1280 height:720];
    [self recordTestH264ToMp4WithH265FileName:@"video_1280_720_2.h264" width:1280 height:720];
    NSLog(@"%@",NSHomeDirectory());
    
    NSString *mp4FilePath = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).lastObject;
    NSString *h264File = [[NSBundle mainBundle] pathForResource:@"video_480_854.h264" ofType:nil];
    NSString *mp4FileName = [h264File lastPathComponent];
    mp4FileName = [mp4FileName stringByReplacingOccurrencesOfString:@"h264" withString:@"mp4"];
    mp4FilePath = [NSString stringWithFormat:@"%@/ffmpeg%@",mp4FilePath,mp4FileName];
    char *ch = [h264File cStringUsingEncoding:NSUTF8StringEncoding];
    char *cm = [mp4FilePath cStringUsingEncoding:NSUTF8StringEncoding];
    int a = retestff(ch, cm);
}

- (void)recordTestH265ToMp4WithH265FileName:(NSString *)h265FileName {
    NSString *h265FilePath = [[NSBundle mainBundle] pathForResource:h265FileName ofType:nil];
    
    NSString *mp4FilePath = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).lastObject;
    NSString *mp4FileName = [h265FilePath lastPathComponent];
    mp4FileName = [mp4FileName stringByReplacingOccurrencesOfString:@"h265" withString:@"mp4"];
    mp4FilePath = [NSString stringWithFormat:@"%@/%@",mp4FilePath,mp4FileName];
    
    NSString *aacPath = [[NSBundle mainBundle] pathForResource:@"vocal.aac" ofType:nil];
    [ESCFFmpegRecordMp4Tool H265RecordToMP4WithH265FilePath:h265FilePath
                                                aacFilePath:aacPath
                                                mp4FilePath:mp4FilePath
                                                 videoWidth:640
                                                videoHeight:360
                                             videoFrameRate:25
                                          audioSampleFormat:0
                                            audioSampleRate:44100
                                         audioChannelLayout:0
                                              audioChannels:2];
    
//    NSString *aacPath = [[NSBundle mainBundle] pathForResource:@"8000_1_16_1.aac" ofType:nil];
//    [ESCFFmpegRecordMp4Tool H265RecordToMP4WithH265FilePath:h265FilePath
//                                                aacFilePath:aacPath
//                                                mp4FilePath:mp4FilePath
//                                                 videoWidth:640
//                                                videoHeight:360
//                                             videoFrameRate:25
//                                          audioSampleFormat:0
//                                            audioSampleRate:8000
//                                         audioChannelLayout:0
//                                              audioChannels:1];
}

- (void)recordTestH264ToMp4WithH265FileName:(NSString *)h264FileName width:(int)width height:(int)height{
    NSString *h264FilePath = [[NSBundle mainBundle] pathForResource:h264FileName ofType:nil];
    
    NSString *mp4FilePath = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).lastObject;
    NSString *mp4FileName = [h264FilePath lastPathComponent];
    mp4FileName = [mp4FileName stringByReplacingOccurrencesOfString:@"h264" withString:@"mp4"];
    mp4FilePath = [NSString stringWithFormat:@"%@/%@",mp4FilePath,mp4FileName];
    
    NSString *aacPath = [[NSBundle mainBundle] pathForResource:@"vocal.aac" ofType:nil];
    [ESCFFmpegRecordMp4Tool H264RecordToMP4WithH264FilePath:h264FilePath mp4FilePath:mp4FilePath videoWidth:width videoHeight:height videoFrameRate:25];
    
    [self saveVideo:mp4FilePath];
    
//    [ESCFFmpegRecordMp4Tool H264RecordToMP4WithH264FilePath:h264FilePath
//                                                aacFilePath:aacPath
//                                                mp4FilePath:mp4FilePath
//                                                 videoWidth:width
//                                                videoHeight:height
//                                             videoFrameRate:25
//                                          audioSampleFormat:1
//                                            audioSampleRate:44100
//                                         audioChannelLayout:0
//                                              audioChannels:2];
//
//    NSString *aacPath = [[NSBundle mainBundle] pathForResource:@"8000_1_16_1.aac" ofType:nil];
//    [ESCFFmpegRecordMp4Tool H264RecordToMP4WithH264FilePath:h264FilePath
//                                                aacFilePath:aacPath
//                                                mp4FilePath:mp4FilePath
//                                                 videoWidth:width
//                                                videoHeight:height
//                                             videoFrameRate:25
//                                          audioSampleFormat:1
//                                            audioSampleRate:8000
//                                         audioChannelLayout:0
//                                              audioChannels:1];
}

//videoPath为视频下载到本地之后的本地路径
- (void)saveVideo:(NSString *)videoPath{
    
    if (videoPath) {
        NSURL *url = [NSURL URLWithString:videoPath];
        BOOL compatible = UIVideoAtPathIsCompatibleWithSavedPhotosAlbum([url path]);
        if (compatible)
        {
            //保存相册核心代码
            UISaveVideoAtPathToSavedPhotosAlbum([url path], self, @selector(savedPhotoImage:didFinishSavingWithError:contextInfo:), nil);
        }
    }
}


//保存视频完成之后的回调
- (void) savedPhotoImage:(UIImage*)image didFinishSavingWithError: (NSError *)error contextInfo: (void *)contextInfo {
    if (error) {
        NSLog(@"保存视频失败%@", error.localizedDescription);
    }
    else {
        NSLog(@"保存视频成功");
    }
}
@end
