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

@interface ESCFFmpegRecordMp4Tool ()

@property(nonatomic,assign)AVFormatContext* formatContext;

@property(nonatomic,assign)AVStream* out_video_stream;

@property(nonatomic,assign)AVStream* out_audio_stream;

@property(nonatomic,assign)AVRational video_baseTime;

@property(nonatomic,assign)AVRational audio_baseTime;

@property(nonatomic,assign)int videoFrameRate;

@property(nonatomic,assign)int width;

@property(nonatomic,assign)int height;

@property(nonatomic,copy)NSString* filePath;

@property(nonatomic,assign)int audioSampleFormat;

@property(nonatomic,assign)int audioSampleRate;

@property(nonatomic,assign)int audioChannelLayout;

@property(nonatomic,assign)int audioChannels;

@property(nonatomic,assign)int64_t v_pts;

@property(nonatomic,assign)int64_t v_dts;

@property(nonatomic,assign)int64_t a_pts;

@property(nonatomic,assign)int64_t a_dts;

@property(nonatomic,assign)ESCVideoCodecType videoCodeType;

@property(nonatomic,assign)BOOL getH264Extradata;

@end

@implementation ESCFFmpegRecordMp4Tool

+ (instancetype)recordFileWithFilePath:(NSString *)filePath
                             codecType:(ESCVideoCodecType)codecType
                            videoWidth:(int)videoWidth
                           videoHeight:(int)videoHeight
                        videoFrameRate:(int)videoFrameRate {
    
    ESCFFmpegRecordMp4Tool *record = [[ESCFFmpegRecordMp4Tool alloc] init];
    
    record.videoCodeType = codecType;
    record.videoFrameRate = videoFrameRate;
    record.width = videoWidth;
    record.height = videoHeight;
    record.filePath = filePath;
    
    BOOL allocFormatContext = [record allocFormatContext];
    if (allocFormatContext == NO) {
        return nil;
    }
    
    BOOL createVideoStream = [record createVideoStream];
    if(createVideoStream == NO) {
        avformat_free_context(record.formatContext);
        printf("create video stream failed!\n");
        return nil;
    }
    
    BOOL openFile = [record openFileAndWriteHeader];
    if (openFile == NO) {
        return nil;
    }
    
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
    
    
    ESCFFmpegRecordMp4Tool *record = [[ESCFFmpegRecordMp4Tool alloc] init];
    
    record.videoCodeType = codecType;
    record.videoFrameRate = videoFrameRate;
    record.width = videoWidth;
    record.height = videoHeight;
    record.filePath = filePath;
    record.audioSampleFormat = audioSampleFormat;
    record.audioSampleRate = audioSampleRate;
    record.audioChannelLayout = audioChannelLayout;
    record.audioChannels = audioChannels;
    
    
    BOOL allocFormatContext = [record allocFormatContext];
    if (allocFormatContext == NO) {
        return nil;
    }
    
    BOOL createVideoStream = [record createVideoStream];
    if(createVideoStream == NO) {
        avformat_free_context(record.formatContext);
        printf("create video stream failed!\n");
        return nil;
    }
   
    BOOL createAudioStream = [record createAudioStream];
    if(createAudioStream == NO) {
        avformat_free_context(record.formatContext);
        printf("create audio stream failed!\n");
        return nil;
    }
    
    BOOL openFile = [record openFileAndWriteHeader];
    if (openFile == NO) {
        return nil;
    }
    
    return record;
}

- (BOOL)allocFormatContext {
    av_register_all();
    avcodec_register_all();
    
    AVFormatContext *formatContext;
    
    const char *fileCharPath = [self.filePath cStringUsingEncoding:NSUTF8StringEncoding];
    NSInteger ret = avformat_alloc_output_context2(&formatContext, NULL, NULL, fileCharPath);
    if (formatContext == nil) {
        printf("formatContext alloc failed!");
        return nil;
    }
    self.formatContext = formatContext;
    
    AVOutputFormat *ofmt = NULL;
    
    ofmt = formatContext->oformat;
    
    if (ret < 0) {
        printf("alloc failed!");
        return nil;
    }
    
    if (self.videoCodeType == ESCVideoCodecTypeH264) {
        formatContext->video_codec_id = AV_CODEC_ID_H264;
    }else if(self.videoCodeType == ESCVideoCodecTypeH265) {
        formatContext->video_codec_id = AV_CODEC_ID_H265;
    }
    return YES;
}

- (BOOL)openFileAndWriteHeader {
    const char *fileCharPath = [self.filePath cStringUsingEncoding:NSUTF8StringEncoding];
    
    //打印
    av_dump_format(_formatContext, 0, fileCharPath, 1);
    
    int ret = avio_open(&_formatContext->pb, fileCharPath, AVIO_FLAG_WRITE);
    if (ret < 0) {
        printf("open io failed!");
        return NO;
    }
    
    printf("start write header!\n");
    ret = avformat_write_header(_formatContext, NULL);
    if (ret < 0) {
        printf("write header failed!");
        return NO;
    }else {
        printf("write header success!\n");
        return YES;
    }
}

- (BOOL)createAudioStream {
    AVStream *out_audio_stream = avformat_new_stream(_formatContext, NULL);
    if (out_audio_stream == NULL) {
        printf("create audio stream failed!");
        return nil;
    }
    
    out_audio_stream->time_base = (AVRational){ 1, self.audioSampleRate };
    self.audio_baseTime = out_audio_stream->time_base;
    
    AVCodecParameters *audioParameters = out_audio_stream->codecpar;
    audioParameters->sample_rate = self.audioSampleRate;
    //AVSampleFormat
    audioParameters->codec_type = AVMEDIA_TYPE_AUDIO;
    audioParameters->codec_id = AV_CODEC_ID_AAC;
    audioParameters->format = AV_SAMPLE_FMT_FLTP;
    audioParameters->bit_rate = 80275;//
    audioParameters->channels = self.audioChannels;
    audioParameters->channel_layout = self.audioChannelLayout;
    audioParameters->frame_size = 1024;
    //    audioParameters->channels = av_get_channel_layout_nb_channels(audioParameters->channel_layout);
    self.out_audio_stream = out_audio_stream;
    
    return YES;
}

- (BOOL)createVideoStream {
    
    AVStream *o_video_stream = avformat_new_stream(_formatContext, NULL);
    if (o_video_stream == NULL) {
        printf("create video stream failed!");
        return NO;
    }
    
    o_video_stream->time_base = (AVRational){ 1, self.videoFrameRate };
    self.video_baseTime = o_video_stream->time_base;
    o_video_stream->codecpar->codec_tag = 0;
    
    
    o_video_stream->codecpar->bit_rate = 1200000;
    o_video_stream->codecpar->codec_type = AVMEDIA_TYPE_VIDEO;
    o_video_stream->codecpar->codec_id = _formatContext->video_codec_id;
    o_video_stream->codecpar->width = self.width;
    o_video_stream->codecpar->height = self.height;
    o_video_stream->codecpar->format = AV_PIX_FMT_YUVJ420P;
    
    self.out_video_stream = o_video_stream;
    
    return YES;

}

- (BOOL)getPPsAndSPS:(void *)data length:(int)length {
    if (self.getH264Extradata == YES) {
        return YES;
    }
    
    int8_t *videoData = (int8_t *)data;
    int lastJ = 0;
    int lastType = 0;
    
    BOOL getSPS = NO;
    BOOL getPPS = NO;
    NSData *pps = nil;
    NSData *sps = nil;
    
    for (int i = 0; i < length - 1; i++) {
        if (getPPS == YES && getSPS == YES) {
            break;
        }
        //读取头
        if (videoData[i] == 0x00 &&
            videoData[i + 1] == 0x00 &&
            videoData[i + 2] == 0x00 &&
            videoData[i + 3] == 0x01) {
            if (i >= 0) {
                uint8_t NALU = videoData[i+4];
                int type = NALU & 0x1f;
                if (lastType == 8 && getPPS == NO) {
                    //get pps
                    getPPS = YES;
                    int frame_size = i - lastJ;
                    pps = [NSData dataWithBytes:&videoData[lastJ] length:frame_size];
                    lastJ = i;
                }else if(lastType == 7 && getSPS == NO) {
                    //get sps
                    getSPS = YES;
                    int frame_size = i - lastJ;
                    sps = [NSData dataWithBytes:&videoData[lastJ] length:frame_size];
                    lastJ = i;
                }
                lastType = type;
            }
        }else if (i == length - 1) {
            if (lastType == 8 && getPPS == NO) {
                //get pps
                getPPS = YES;
                int frame_size = i - lastJ;
                pps = [NSData dataWithBytes:&videoData[lastJ] length:frame_size];
                lastJ = i;
            }else if(lastType == 7 && getSPS == NO) {
                //get sps
                getSPS = YES;
                int frame_size = i - lastJ;
                sps = [NSData dataWithBytes:&videoData[lastJ] length:frame_size];
                lastJ = i;
            }
            lastJ = i;
        }
    }
    if (getSPS == YES && getPPS == YES) {
        //sps + pps
        self.out_video_stream->codecpar->extradata_size = (int)sps.length + (int)pps.length;
        uint8_t *resultd = av_malloc(sps.length + pps.length);
        int8_t *spsData = (int8_t *)[sps bytes];
        int8_t *ppsData = (int8_t *)[pps bytes];
        for (int i = 0; i < sps.length; i++) {
            resultd[i] = spsData[i];
        }
        for (int i = 0; i < pps.length; i++) {
            resultd[i + sps.length] = ppsData[i];
        }
        self.out_video_stream->codecpar->extradata = resultd;
        self.getH264Extradata = YES;
        return YES;
    }else {
        return NO;
    }
}

- (void)writeVideoFrame:(void *)data length:(int)length {
    //读取pps和sps
    if (self.videoCodeType == ESCVideoCodecTypeH264) {
        BOOL isGetPPSAndSPS = [self getPPsAndSPS:data length:length];
        if (isGetPPSAndSPS == NO) {
            return;
        }
    }
    
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
            }
        }
    }
    i_pkt.dts = self.v_dts;
    i_pkt.pts = self.v_pts;
    self.v_dts++;
    self.v_pts++;
    
    ret = [self writeFrame:_formatContext time_base:&_video_baseTime stream:_out_video_stream packet:&i_pkt];
    av_packet_unref(&i_pkt);
    if (ret != 0) {
        NSLog(@"添加失败");
    }
    
    
}

- (void)writeAudioFrame:(void *)data length:(int)length {
    AVPacket pkt = { 0 }; // data and size must be 0;
    int ret;
//    int dst_nb_samples;
    av_init_packet(&pkt);
    
    uint8_t *pData = data;
    int iLen = length;
    
    pkt.size = iLen;
    pkt.data = pData;
    
    
    //取number_of_raw_data_blocks_in_frame
    uint8_t frameSampleLength = pData[6];
    frameSampleLength = frameSampleLength & 0x3;
    frameSampleLength += 1;
    self.a_dts += 1024 * frameSampleLength;
    self.a_pts += 1024 * frameSampleLength;
    
    NSLog(@"%d==%d",frameSampleLength,length);
    
    pkt.dts = self.a_dts;
    pkt.pts = self.a_pts;
    pkt.duration = 1024 * frameSampleLength;
    
    printf("dts  %d  ",pkt.dts);
    printf("pts  %d  ",pkt.pts);
    
//    ret = write_frame(oc, &c->time_base, ost->st, &pkt);
    ret = [self writeFrame:_formatContext time_base:&_audio_baseTime stream:_out_audio_stream packet:&pkt];
    if (ret < 0) {
        fprintf(stderr, "%d======failed error while writing audio frame: %s\n",length,av_err2str(ret));
//        exit(1);
        self.a_dts -= 1024 * frameSampleLength;
        self.a_pts -= 1024 * frameSampleLength;
        return;
    }else {
//        printf("%d==add audio success!\n",length);
    }
    
}

- (int)writeFrame:(AVFormatContext*)fmt_ctx
        time_base:(AVRational *)time_base
           stream:(AVStream *)stream
           packet:(AVPacket *)pkt {
    av_packet_rescale_ts(pkt, *time_base, stream->time_base);
    pkt->stream_index = stream->index;
    return av_interleaved_write_frame(fmt_ctx, pkt);
}

- (void)stopRecord {
    if( _formatContext ) {
        int ret = av_write_trailer(_formatContext);
        if(ret != 0) {
            NSLog(@"结束文件失败");
        }else {
            NSLog(@"结束文件成功");
        }

        avio_close(_formatContext->pb);
        avformat_free_context(_formatContext);
    }
}

@end
