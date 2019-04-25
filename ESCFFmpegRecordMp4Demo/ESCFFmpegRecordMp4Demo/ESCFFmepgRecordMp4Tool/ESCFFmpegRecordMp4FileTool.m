//
//  ESCFFmpegRecordMp4FileTool.m
//  ESCFFmpegRecordMp4Demo
//
//  Created by xiang on 2019/4/25.
//  Copyright © 2019 xiang. All rights reserved.
//

#import "ESCFFmpegRecordMp4FileTool.h"
#import "ESCFFmpegRecordMp4Tool.h"

@implementation ESCFFmpegRecordMp4FileTool

+ (void)H265RecordToMP4WithH265FilePath:(NSString *)h265FilePath
                            mp4FilePath:(NSString *)mp4FilePath
                             videoWidth:(int)videoWidth
                            videoHeight:(int)videoHeight
                         videoFrameRate:(int)videoFrameRate {
    
    NSData *h265Data = [NSData dataWithContentsOfFile:h265FilePath];
    
    ESCFFmpegRecordMp4Tool *tool = [ESCFFmpegRecordMp4Tool recordFileWithFilePath:mp4FilePath
                                                                        codecType:ESCVideoCodecTypeH265
                                                                       videoWidth:videoWidth
                                                                      videoHeight:videoHeight
                                                                   videoFrameRate:videoFrameRate];
    
    int8_t *videoData = (int8_t *)[h265Data bytes];
    int lastJ = 0;
    int lastType = 0;
    
    for (int i = 0; i < h265Data.length - 1; i++) {
        //读取头
        if (videoData[i] == 0x00 &&
            videoData[i + 1] == 0x00 &&
            videoData[i + 2] == 0x00 &&
            videoData[i + 3] == 0x01) {
            if (i >= 0) {
                //读取类型
                int type = (videoData[i + 4] & 0x7E)>>1;
                if (lastType == 1 || lastType == 19) {
                    int frame_size = i - lastJ;
                    [tool writeVideoFrame:&videoData[lastJ] length:frame_size];
                    lastJ = i;
                }
                lastType = type;
            }
        }else if (i == h265Data.length - 1) {
            int frame_size = i - lastJ;
            [tool writeVideoFrame:&videoData[lastJ] length:frame_size];
            lastJ = i;
        }
    }
    
    [tool stopRecord];
    NSLog(@"完成");
    
}

+ (void)H265RecordToMP4WithH265FilePath:(NSString *)h265FilePath
                            aacFilePath:(NSString *)aacFilePath
                            mp4FilePath:(NSString *)mp4FilePath
                             videoWidth:(int)videoWidth
                            videoHeight:(int)videoHeight
                         videoFrameRate:(int)videoFrameRate
                      audioSampleFormat:(int)audioSampleFormat
                        audioSampleRate:(int)audioSampleRate
                     audioChannelLayout:(int)audioChannelLayout
                          audioChannels:(int)audioChannels {
    
    NSData *h265Data = [NSData dataWithContentsOfFile:h265FilePath];
    
    ESCFFmpegRecordMp4Tool *tool = [ESCFFmpegRecordMp4Tool recordFileWithFilePath:mp4FilePath
                                                                        codecType:ESCVideoCodecTypeH265
                                                                       videoWidth:videoWidth
                                                                      videoHeight:videoHeight
                                                                   videoFrameRate:videoFrameRate
                                                                audioSampleFormat:audioSampleFormat
                                                                  audioSampleRate:audioSampleRate
                                                               audioChannelLayout:audioChannelLayout
                                                                    audioChannels:audioChannels];
    
    int8_t *videoData = (int8_t *)[h265Data bytes];
    int lastJ = 0;
    int lastType = 0;
    
    for (int i = 0; i < h265Data.length - 1; i++) {
        //读取头
        if (videoData[i] == 0x00 &&
            videoData[i + 1] == 0x00 &&
            videoData[i + 2] == 0x00 &&
            videoData[i + 3] == 0x01) {
            if (i >= 0) {
                //读取类型
                int type = (videoData[i + 4] & 0x7E)>>1;
                if (lastType == 1 || lastType == 19) {
                    int frame_size = i - lastJ;
                    [tool writeVideoFrame:&videoData[lastJ] length:frame_size];
                    lastJ = i;
                }
                lastType = type;
            }
        }else if (i == h265Data.length - 1) {
            int frame_size = i - lastJ;
            [tool writeVideoFrame:&videoData[lastJ] length:frame_size];
            lastJ = i;
        }
    }
    
    NSData *aacData = [NSData dataWithContentsOfFile:aacFilePath];
    uint8_t *voiceData = (uint8_t*)[aacData bytes];
    int j = 0;
    lastJ = 0;
    while (j < aacData.length) {
        if (voiceData[j] == 0xff &&
            (voiceData[j + 1] & 0xf0) == 0xf0) {
            if (j > 0) {
                //0xfff判断AAC头
                int frame_size = j - lastJ;
                if (frame_size > 7) {
                    [tool writeAudioFrame:&voiceData[lastJ] length:frame_size];
                    lastJ = j;
                }
            }
        }else if (j == aacData.length - 1) {
            int frame_size = j - lastJ;
            if (frame_size > 7) {
                [tool writeAudioFrame:&voiceData[lastJ] length:frame_size];
                lastJ = j;
            }
        }
        j++;
    }
    
    
    [tool stopRecord];
    NSLog(@"完成");
    
}


+ (void)H264RecordToMP4WithH264FilePath:(NSString *)h264FilePath
                            mp4FilePath:(NSString *)mp4FilePath
                             videoWidth:(int)videoWidth
                            videoHeight:(int)videoHeight
                         videoFrameRate:(int)videoFrameRate {
    NSData *h264Data = [NSData dataWithContentsOfFile:h264FilePath];
    
    ESCFFmpegRecordMp4Tool *tool = [ESCFFmpegRecordMp4Tool recordFileWithFilePath:mp4FilePath
                                                                        codecType:ESCVideoCodecTypeH264
                                                                       videoWidth:videoWidth
                                                                      videoHeight:videoHeight
                                                                   videoFrameRate:videoFrameRate];
    
    int8_t *videoData = (int8_t *)[h264Data bytes];
    int lastJ = 0;
    int lastType = 0;
    
    for (int i = 0; i < h264Data.length - 1; i++) {
        //读取头
        if (videoData[i] == 0x00 &&
            videoData[i + 1] == 0x00 &&
            videoData[i + 2] == 0x00 &&
            videoData[i + 3] == 0x01) {
            if (i >= 0) {
                uint8_t NALU = videoData[i+4];
                int type = NALU & 0x1f;
                //                NSLog(@"%d===%d",type,NALU);
                if (lastType == 5 || lastType == 1) {
                    int frame_size = i - lastJ;
                    [tool writeVideoFrame:&videoData[lastJ] length:frame_size];
                    lastJ = i;
                }
                lastType = type;
            }
        }else if (i == h264Data.length - 1) {
            int frame_size = i - lastJ;
            [tool writeVideoFrame:&videoData[lastJ] length:frame_size];
            lastJ = i;
        }
    }
    
    [tool stopRecord];
    NSLog(@"完成");
}

+ (int8_t *)Annex_BToAvcc:(int8_t *)data length:(int)length {
    NSData *data1 = [NSData dataWithBytes:(data+4) length:length - 4];
    int8_t header[4] = {0};
    int len = length - 4;
    header[0] = len >> 24;
    header[1] = len >> 16;
    header[2] = len >> 8;
    header[3] = len & 0xff;
    
    NSMutableData *resultData = [NSMutableData dataWithBytes:header length:4];
    [resultData appendData:data1];
    int8_t *result = (int8_t *)[resultData bytes];
    return result;
}

+ (void)H264RecordToMP4WithH264FilePath:(NSString *)h264FilePath
                            aacFilePath:(NSString *)aacFilePath
                            mp4FilePath:(NSString *)mp4FilePath
                             videoWidth:(int)videoWidth
                            videoHeight:(int)videoHeight
                         videoFrameRate:(int)videoFrameRate
                      audioSampleFormat:(int)audioSampleFormat
                        audioSampleRate:(int)audioSampleRate
                     audioChannelLayout:(int)audioChannelLayout
                          audioChannels:(int)audioChannels {
    NSData *h264Data = [NSData dataWithContentsOfFile:h264FilePath];
    
    ESCFFmpegRecordMp4Tool *tool;
    if (aacFilePath == nil) {
        tool = [ESCFFmpegRecordMp4Tool recordFileWithFilePath:mp4FilePath
                                                    codecType:ESCVideoCodecTypeH264
                                                   videoWidth:videoWidth
                                                  videoHeight:videoHeight
                                               videoFrameRate:videoFrameRate];
        
    }else {
        tool = [ESCFFmpegRecordMp4Tool recordFileWithFilePath:mp4FilePath
                                                    codecType:ESCVideoCodecTypeH264
                                                   videoWidth:videoWidth
                                                  videoHeight:videoHeight
                                               videoFrameRate:videoFrameRate
                                            audioSampleFormat:1
                                              audioSampleRate:audioSampleRate
                                           audioChannelLayout:0
                                                audioChannels:audioChannels];
    }
    int8_t *videoData = (int8_t *)[h264Data bytes];
    int lastJ = 0;
    int lastType = 0;
    
    for (int i = 0; i < h264Data.length - 1; i++) {
        //读取头
        if (videoData[i] == 0x00 &&
            videoData[i + 1] == 0x00 &&
            videoData[i + 2] == 0x00 &&
            videoData[i + 3] == 0x01) {
            if (i >= 0) {
                uint8_t NALU = videoData[i+4];
                int type = NALU & 0x1f;
                //                NSLog(@"%d===%d",type,NALU);
                if (lastType == 5 || lastType == 1) {
                    int frame_size = i - lastJ;
                    //                    NSLog(@"%d",frame_size);
                    [tool writeVideoFrame:&videoData[lastJ] length:frame_size];
                    lastJ = i;
                }
                lastType = type;
            }
        }else if (i == h264Data.length - 1) {
            int frame_size = i - lastJ;
            //            NSLog(@"%d",frame_size);
            [tool writeVideoFrame:&videoData[lastJ] length:frame_size];
            lastJ = i;
        }
    }
    
    NSData *aacData = [NSData dataWithContentsOfFile:aacFilePath];
    uint8_t *voiceData = (uint8_t*)[aacData bytes];
    int j = 0;
    lastJ = 0;
    while (j < aacData.length) {
        if (voiceData[j] == 0xff &&
            (voiceData[j + 1] & 0xf0) == 0xf0) {
            if (j > 0) {
                //0xfff判断AAC头
                int frame_size = j - lastJ;
                if (frame_size > 7) {
                    [tool writeAudioFrame:&voiceData[lastJ + 7] length:frame_size - 7];
                    //                    NSLog(@"%@",[NSData dataWithBytes:&voiceData[lastJ] length:frame_size]);
                    lastJ = j;
                }
            }
        }else if (j == aacData.length - 1) {
            int frame_size = j - lastJ;
            if (frame_size > 7) {
                [tool writeAudioFrame:&voiceData[lastJ + 7] length:frame_size - 7];
                lastJ = j;
            }
        }
        j++;
    }
    
    
    [tool stopRecord];
    NSLog(@"完成");
}


@end
