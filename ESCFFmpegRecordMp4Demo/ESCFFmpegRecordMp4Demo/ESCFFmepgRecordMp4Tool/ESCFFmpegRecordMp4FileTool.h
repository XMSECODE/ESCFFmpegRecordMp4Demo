//
//  ESCFFmpegRecordMp4FileTool.h
//  ESCFFmpegRecordMp4Demo
//
//  Created by xiang on 2019/4/25.
//  Copyright © 2019 xiang. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ESCFFmpegRecordMp4FileTool : NSObject

+ (void)H265RecordToMP4WithH265FilePath:(NSString *)h265FilePath
                            mp4FilePath:(NSString *)mp4FilePath
                             videoWidth:(int)videoWidth
                            videoHeight:(int)videoHeight
                         videoFrameRate:(int)videoFrameRate;

+ (void)H265RecordToMP4WithH265FilePath:(NSString *)h265FilePath
                            aacFilePath:(NSString *)aacFilePath
                            mp4FilePath:(NSString *)mp4FilePath
                             videoWidth:(int)videoWidth
                            videoHeight:(int)videoHeight
                         videoFrameRate:(int)videoFrameRate
                      audioSampleFormat:(int)audioSampleFormat
                        audioSampleRate:(int)audioSampleRate
                     audioChannelLayout:(int)audioChannelLayout
                          audioChannels:(int)audioChannels;

+ (void)H264RecordToMP4WithH264FilePath:(NSString *)h264FilePath
                            mp4FilePath:(NSString *)mp4FilePath
                             videoWidth:(int)videoWidth
                            videoHeight:(int)videoHeight
                         videoFrameRate:(int)videoFrameRate;

+ (void)H264RecordToMP4WithH264FilePath:(NSString *)h264FilePath
                            aacFilePath:(NSString *)aacFilePath
                            mp4FilePath:(NSString *)mp4FilePath
                             videoWidth:(int)videoWidth
                            videoHeight:(int)videoHeight
                         videoFrameRate:(int)videoFrameRate
                      audioSampleFormat:(int)audioSampleFormat
                        audioSampleRate:(int)audioSampleRate
                     audioChannelLayout:(int)audioChannelLayout
                          audioChannels:(int)audioChannels;

@end

NS_ASSUME_NONNULL_END
