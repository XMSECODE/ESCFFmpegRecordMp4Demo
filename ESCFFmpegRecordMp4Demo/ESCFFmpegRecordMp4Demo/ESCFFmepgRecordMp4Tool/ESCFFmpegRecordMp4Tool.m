//
//  ANNffmpegRecorder.m
//  CloudViews
//
//  Created by xiang on 2018/8/9.
//  Copyright © 2018年 mac. All rights reserved.
//

#import "ESCFFmpegRecordMp4Tool.h"
#import <libavutil/avassert.h>
#import <libavutil/channel_layout.h>
#import <libavutil/opt.h>
#import <libavutil/mathematics.h>
#import <libavutil/timestamp.h>
#import <libavformat/avformat.h>
#import <libswscale/swscale.h>
#import <libswresample/swresample.h>

#define MAX_NALUS_SZIE (5000)


@interface ESCFFmpegRecordMp4Tool ()

@property(nonatomic,assign)AVFormatContext *formatContext;

@property(nonatomic,assign)    AVStream * o_video_stream;

@property(nonatomic,assign)AVRational baseTime;

@property(nonatomic,assign)char *strH264Nalu;

@property(nonatomic,assign)int iH264NaluSize;

@property(nonatomic,assign)int64_t v_pts;

@property(nonatomic,assign)int64_t v_dts;

@property(nonatomic,assign)int64_t a_pts;

@property(nonatomic,assign)int64_t a_dts;

@property(nonatomic,assign)ESCVideoCodecType videoCodeType;

@end

@implementation ESCFFmpegRecordMp4Tool

+ (instancetype)recordFileWithFilePath:(NSString *)filePath
                             codecType:(ESCVideoCodecType)codecType
                            videoWidth:(int)videoWidth
                           videoHeight:(int)videoHeight
                        videoFrameRate:(int)videoFrameRate {
    
    av_register_all();
    avcodec_register_all();

    ESCFFmpegRecordMp4Tool *record = [[ESCFFmpegRecordMp4Tool alloc] init];
    char strh264nalu[MAX_NALUS_SZIE] = {0};
    
    record.strH264Nalu = strh264nalu;
    record.videoCodeType = codecType;
    
    AVFormatContext *formatContext;
    const char *fileCharPath = [filePath cStringUsingEncoding:NSUTF8StringEncoding];
    NSInteger ret = avformat_alloc_output_context2(&formatContext, NULL, NULL, fileCharPath);
    if (formatContext == nil) {
        printf("formatContext alloc failed!");
        return nil;
    }
    
    if (codecType == ESCVideoCodecTypeH264) {
        formatContext->video_codec_id = AV_CODEC_ID_H264;
    }else if(codecType == ESCVideoCodecTypeH265) {
        formatContext->video_codec_id = AV_CODEC_ID_H265;
    }
    
    if (ret < 0) {
        printf("alloc failed!");
        return nil;
    }
    if (!formatContext) {
        printf("Could not deduce output format from file extension\n");
        return nil;
    }
    
    
    AVStream *o_video_stream = avformat_new_stream(formatContext, NULL);
    
    o_video_stream->time_base = (AVRational){ 1, videoFrameRate };
    record.baseTime = o_video_stream->time_base;
    
        
    AVCodecParameters *parameters = o_video_stream->codecpar;
    parameters->bit_rate = 1200000;
    parameters->codec_type = AVMEDIA_TYPE_VIDEO;
    parameters->codec_id = formatContext->video_codec_id;
    parameters->width = videoWidth;
    parameters->height = videoHeight;
    parameters->format = AV_PIX_FMT_YUVJ420P;
    
    av_dump_format(formatContext, 0, fileCharPath, 1);
    
    ret = avio_open(&formatContext->pb, fileCharPath, AVIO_FLAG_WRITE);
    if (ret < 0) {
        printf("open io failed!");
        return nil;
    }
    
    ret = avformat_write_header(formatContext, NULL);
    if (ret < 0) {
        printf("write header failed!");
        return nil;
    }
    
    record.formatContext = formatContext;
    record.o_video_stream = o_video_stream;
    return record;
}

+ (instancetype)recordFileWithFilePath:(NSString *)filePath
                             codecType:(int)codecType
                            videoWidth:(int)videoWidth
                           videoHeight:(int)videoHeight
                        videoFrameRate:(int)videoFrameRate
                     audioSampleFormat:(int)audioSampleFormat
                       audioSampleRate:(int)audioSampleRate
                    audioChannelLayout:(int)audioChannelLayout
                         audioChannels:(int)audioChannels {
    return nil;
}

- (void)writeVideoFrame:(void *)data length:(int)length {
    
    uint8_t *pData = data;
    int iLen = length;
    int ret = 0;
    AVPacket i_pkt;
    av_init_packet(&i_pkt);
    i_pkt.size = iLen;
    i_pkt.data = pData;
    
    if (self.videoCodeType == ESCVideoCodecTypeH265) {
        //h265
        if( pData[0] == 0x00 && pData[1] == 0x00 && pData[2] == 0x00 && pData[3] == 0x01 &&  pData[4] == 0x40 ){
            //标记为关键帧
            i_pkt.flags |= AV_PKT_FLAG_KEY;
            //        NSLog(@"关键帧");
        }
    }else if (self.videoCodeType == ESCVideoCodecTypeH264) {
        //h264
        if( pData[0] == 0x00 && pData[1] == 0x00 && pData[2] == 0x00 && pData[3] == 0x01){
            if ((pData[4] & 0x1f) == 7) {
                //标记为关键帧
                i_pkt.flags |= AV_PKT_FLAG_KEY;
                //        NSLog(@"关键帧");
            }
        }
    }
    self.v_dts++;
    self.v_pts++;
    i_pkt.dts = self.v_dts;
    i_pkt.pts = self.v_pts;
    
    ret = [self writeFrame:_formatContext time_base:&_baseTime stream:_o_video_stream packet:&i_pkt];
    
    if (ret != 0) {
        NSLog(@"添加失败");
    }
    
    
}

- (int)writeFrame:(AVFormatContext*)fmt_ctx time_base:(AVRational *)time_base stream:(AVStream *)stream packet:(AVPacket *)pkt {
    /* rescale output packet timestamp values from codec to stream timebase */
//    printf("%d==%d===%d==%d\n",time_base->num,time_base->den,stream->time_base.num,stream->time_base.den);
    av_packet_rescale_ts(pkt, *time_base, stream->time_base);
    pkt->stream_index = stream->index;
//    printf("%d===%d\n",pkt->dts,pkt->pts);
//    NSLog(@"%d",stream->index);
//    return av_write_frame(fmt_ctx, pkt);
    return av_interleaved_write_frame(fmt_ctx, pkt);
}

- (void)writeAudioFrame:(void *)data length:(int)length {
    
}

- (void)stopRecord {
    if( _formatContext )
    {
        av_write_trailer(_formatContext);
        
        //        if( pFormat->o_audio_stream )
        //        {
        //            avcodec_close(pFormat->o_audio_stream->codec);
        //            av_frame_free(&pFormat->frame);
        //            av_frame_free(&pFormat->tmp_frame);
        //            swr_free(&pFormat->swr_ctx);
        //        }
        
        
        if(_o_video_stream){
            _o_video_stream->codecpar->extradata_size = 0;
//            _o_video_stream->codec->extradata_size = 0;
            _o_video_stream->codecpar->extradata = NULL;
//            _o_video_stream->codec->extradata = NULL;
//            avcodec_close(_o_video_stream->codec);
        }
        
        avio_close(_formatContext->pb);
        avformat_free_context(_formatContext);
    }
}

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

@end
