//
//  ANNffmpegRecorder.h
//  CloudViews
//
//  Created by xiang on 2018/8/9.
//  Copyright © 2018年 mac. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum : NSUInteger {
    ESCVideoCodecTypeH264,
    ESCVideoCodecTypeH265,
} ESCVideoCodecType;

@interface ESCFFmpegRecordMp4Tool : NSObject

+ (instancetype)recordFileWithFilePath:(NSString *)filePath
                             codecType:(ESCVideoCodecType)codecType
                            videoWidth:(int)videoWidth
                           videoHeight:(int)videoHeight
                        videoFrameRate:(int)videoFrameRate;

+ (instancetype)recordFileWithFilePath:(NSString *)filePath
                             codecType:(int)codecType
                            videoWidth:(int)videoWidth
                           videoHeight:(int)videoHeight
                        videoFrameRate:(int)videoFrameRate
                     audioSampleFormat:(int)audioSampleFormat
                       audioSampleRate:(int)audioSampleRate
                    audioChannelLayout:(int)audioChannelLayout
                         audioChannels:(int)audioChannels;

- (void)writeVideoFrame:(void *)data
                 length:(int)length;

- (void)writeAudioFrame:(void *)data
                 length:(int)length;

- (void)stopRecord;

@end
