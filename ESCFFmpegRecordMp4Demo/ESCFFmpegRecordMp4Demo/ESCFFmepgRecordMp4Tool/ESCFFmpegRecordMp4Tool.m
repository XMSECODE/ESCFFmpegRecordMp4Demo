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

@property(nonatomic,assign)AVFormatContext *formatContext;

@property(nonatomic,assign)AVStream * o_video_stream;

@property(nonatomic,assign)AVStream *out_audio_stream;

@property(nonatomic,assign)AVRational video_baseTime;

@property(nonatomic,assign)AVRational audio_baseTime;

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
    
    av_register_all();
    avcodec_register_all();
    
    ESCFFmpegRecordMp4Tool *record = [[ESCFFmpegRecordMp4Tool alloc] init];
    
    record.videoCodeType = codecType;
    
    AVFormatContext *formatContext;
    const char *fileCharPath = [filePath cStringUsingEncoding:NSUTF8StringEncoding];
    NSInteger ret = avformat_alloc_output_context2(&formatContext, NULL, NULL, fileCharPath);
    if (formatContext == nil) {
        printf("formatContext alloc failed!");
        return nil;
    }
    AVOutputFormat *ofmt = NULL;

    ofmt = formatContext->oformat;

    if (ret < 0) {
        printf("alloc failed!");
        return nil;
    }
    
    /*===========================video stream=============================================================================================================*/
    if (codecType == ESCVideoCodecTypeH264) {
        formatContext->video_codec_id = AV_CODEC_ID_H264;
    }else if(codecType == ESCVideoCodecTypeH265) {
        formatContext->video_codec_id = AV_CODEC_ID_H265;
    }
    
    
   
    AVStream *o_video_stream = avformat_new_stream(formatContext, NULL);
    if (o_video_stream == NULL) {
        printf("create video stream failed!");
        return nil;
    }
    
    o_video_stream->time_base = (AVRational){ 1, videoFrameRate };
    record.video_baseTime = o_video_stream->time_base;
    o_video_stream->codecpar->codec_tag = 0;

    
    o_video_stream->codecpar->bit_rate = 1200000;
    o_video_stream->codecpar->codec_type = AVMEDIA_TYPE_VIDEO;
    o_video_stream->codecpar->codec_id = formatContext->video_codec_id;
    o_video_stream->codecpar->width = videoWidth;
    o_video_stream->codecpar->height = videoHeight;
    o_video_stream->codecpar->format = AV_PIX_FMT_YUVJ420P;
    /*=======================================================================================================================================*/
    {
//        o_video_stream->codecpar->codec_tag = 0;
//        o_video_stream->codecpar->bit_rate = 0;
//        o_video_stream->codecpar->bits_per_raw_sample = 8;
//        o_video_stream->codecpar->bits_per_coded_sample = 0;
//        o_video_stream->codecpar->profile = 100;
//        o_video_stream->codecpar->level = 31;
//        AVRational rationa;
//        rationa.num = 0;
//        rationa.den = 1;
//        o_video_stream->codecpar->sample_aspect_ratio = rationa;
//        o_video_stream->codecpar->field_order = AV_FIELD_PROGRESSIVE;
//        o_video_stream->codecpar->color_range = AVCOL_RANGE_JPEG;
//        o_video_stream->codecpar->color_primaries = AVCOL_PRI_UNSPECIFIED;
//        o_video_stream->codecpar->color_trc = AVCOL_TRC_UNSPECIFIED;
//        o_video_stream->codecpar->color_space = AVCOL_SPC_UNSPECIFIED;
//        o_video_stream->codecpar->chroma_location = AVCHROMA_LOC_LEFT;
//        o_video_stream->codecpar->video_delay = 0;
//        o_video_stream->codecpar->channel_layout = 0;
//        o_video_stream->codecpar->sample_rate = 0;
//        o_video_stream->codecpar->frame_size = 0;
//        o_video_stream->codecpar->initial_padding = 0;
//        o_video_stream->codecpar->trailing_padding = 0;
//        o_video_stream->codecpar->seek_preroll = 0;


//        o_video_stream->codecpar->extradata_size = 32;
//        int8_t testdata[32] = {0x00,0x00,0x00,0x01,0x27,0x64,0x00,0x1F,0xAC,0x56,0x50,0x78,0x1B,0x7E,0x69,0xB8,0x10,0x10,0x10,0x36,0x82,0x21,0x19,0x60,0x00,0x00,0x00,0x01,0x28,0xEE,0x37,0x27};
////        000000142764001FAC5650781B7E69B810101036822119600000000428EE3727
//        uint8_t *resultd = av_malloc(32);
//        for (int i = 0; i < 32; i++) {
//            resultd[i] = testdata[i];
//        }
//        o_video_stream->codecpar->extradata = resultd;
    }
    av_dump_format(formatContext, 0, fileCharPath, 1);
    
    ret = avio_open(&formatContext->pb, fileCharPath, AVIO_FLAG_WRITE);
    if (ret < 0) {
        printf("open io failed!");
        return nil;
    }
    AVDictionary *opt = NULL;
//    ret = av_dict_set(&opt, "movflags", "faststart", 0);
//    if (ret < 0) {
//        printf("set option failed！");
//        return nil;
//    }
    ret = av_dict_set_int(&opt, "framerate", 20, 0);
    if (ret < 0) {
        printf("set option failed！");
        return nil;
    }
    
    printf("start write header!\n");
    ret = avformat_write_header(formatContext, &opt);
    if (ret < 0) {
        printf("write header failed!");
        return nil;
    }else {
        printf("write header success!\n");
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
    
    av_register_all();
    avcodec_register_all();
    
    ESCFFmpegRecordMp4Tool *record = [[ESCFFmpegRecordMp4Tool alloc] init];
    
    record.videoCodeType = codecType;
    
    AVFormatContext *formatContext;
    const char *fileCharPath = [filePath cStringUsingEncoding:NSUTF8StringEncoding];
    NSInteger ret = avformat_alloc_output_context2(&formatContext, NULL, NULL, fileCharPath);
    if (formatContext == nil) {
        printf("formatContext alloc failed!");
        return nil;
    }
    
    if (ret < 0) {
        printf("alloc failed!");
        return nil;
    }
    
    /*===========================video stream=============================================================================================================*/
    if (codecType == ESCVideoCodecTypeH264) {
        formatContext->video_codec_id = AV_CODEC_ID_H264;
    }else if(codecType == ESCVideoCodecTypeH265) {
        formatContext->video_codec_id = AV_CODEC_ID_H265;
    }
    
    
    AVCodec *videoCodec = avcodec_find_encoder(AV_CODEC_ID_H264);
    if (videoCodec) {
        printf("find videocodec success!\n");
    }
    AVStream *o_video_stream = avformat_new_stream(formatContext, videoCodec);
    if (o_video_stream == NULL) {
        printf("create video stream failed!");
        return nil;
    }
    
    o_video_stream->time_base = (AVRational){ 1, videoFrameRate };
    record.video_baseTime = o_video_stream->time_base;
    
    
    AVCodecParameters *parameters = o_video_stream->codecpar;
    parameters->bit_rate = 1200000;
    parameters->codec_type = AVMEDIA_TYPE_VIDEO;
    parameters->codec_id = formatContext->video_codec_id;
    parameters->width = videoWidth;
    parameters->height = videoHeight;
    parameters->format = AV_PIX_FMT_YUV420P;
    
    /*====================================audio stream===================================================================================================*/
    AVCodec *audioCodec = NULL;
    audioCodec = avcodec_find_encoder(AV_CODEC_ID_AAC);
    if (audioCodec) {
        printf("find audioCodec success!\n");
    }
    AVStream *out_audio_stream = avformat_new_stream(formatContext, audioCodec);
    if (out_audio_stream == NULL) {
        printf("create audio stream failed!");
        return nil;
    }

    out_audio_stream->time_base = (AVRational){ 1, audioSampleRate };
    record.audio_baseTime = out_audio_stream->time_base;
    
    AVCodecParameters *audioParameters = out_audio_stream->codecpar;
    audioParameters->sample_rate = audioSampleRate;
    //AVSampleFormat
    audioParameters->format = AV_SAMPLE_FMT_S16P;
    audioParameters->codec_id = AV_CODEC_ID_AAC;
    audioParameters->codec_type = AVMEDIA_TYPE_AUDIO;
    audioParameters->bit_rate = 64000;
    audioParameters->channels = audioChannels;
    audioParameters->channel_layout = audioChannelLayout;
//    audioParameters->channels = av_get_channel_layout_nb_channels(audioParameters->channel_layout);
    out_audio_stream->time_base = (AVRational){ 1, parameters->sample_rate};

    /*=======================================================================================================================================*/
    
    
    av_dump_format(formatContext, 0, fileCharPath, 1);
    
    ret = avio_open(&formatContext->pb, fileCharPath, AVIO_FLAG_WRITE);
    if (ret < 0) {
        printf("open io failed!");
        return nil;
    }
//    av_dict_set(<#AVDictionary **pm#>, <#const char *key#>, <#const char *value#>, <#int flags#>)
    AVDictionary *opt = NULL;
    ret = av_dict_set(&opt, "movflags", "faststart", 0);
    if (ret < 0) {
        printf("set option failed！");
        return nil;
    }
    ret = av_dict_set_int(&opt, "framerate", 20, 0);
    if (ret < 0) {
        printf("set option failed！");
        return nil;
    }

    printf("start write header!\n");
    ret = avformat_write_header(formatContext, &opt);
    if (ret < 0) {
        printf("write header failed!");
        return nil;
    }else {
        printf("write header success!\n");
    }
    
    record.formatContext = formatContext;
    record.o_video_stream = o_video_stream;
    record.out_audio_stream = out_audio_stream;
    return record;
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
        self.o_video_stream->codecpar->extradata_size = (int)sps.length + (int)pps.length;
        uint8_t *resultd = av_malloc(sps.length + pps.length);
        int8_t *spsData = (int8_t *)[sps bytes];
        int8_t *ppsData = (int8_t *)[pps bytes];
        for (int i = 0; i < sps.length; i++) {
            resultd[i] = spsData[i];
        }
        for (int i = 0; i < pps.length; i++) {
            resultd[i + sps.length] = ppsData[i];
        }
        self.o_video_stream->codecpar->extradata = resultd;
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
    
    ret = [self writeFrame:_formatContext time_base:&_video_baseTime stream:_o_video_stream packet:&i_pkt];
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
    uint8_t frameSampleLength = pData[7];
    frameSampleLength = frameSampleLength & 0x3;
    frameSampleLength += 1;
    self.a_dts += 1024 * frameSampleLength;
    self.a_pts += 1024 * frameSampleLength;
    
    
    pkt.dts = self.a_dts;
    pkt.pts = self.a_pts;
    
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

- (int)writeFrame:(AVFormatContext*)fmt_ctx time_base:(AVRational *)time_base stream:(AVStream *)stream packet:(AVPacket *)pkt {
    av_packet_rescale_ts(pkt, *time_base, stream->time_base);
    pkt->stream_index = stream->index;
    return av_interleaved_write_frame(fmt_ctx, pkt);
}



- (void)stopRecord {
    if( _formatContext )
    {
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
//                    if (lastType == 5 || lastType == 1 || lastType == 7 || lastType == 8 || lastType == 6) {
                    int frame_size = i - lastJ;
                    int8_t *result = [self Annex_BToAvcc:&videoData[lastJ] length:frame_size];
                    [tool writeVideoFrame:result length:frame_size];
                    lastJ = i;
                }
                lastType = type;
            }
        }else if (i == h264Data.length - 1) {
            int frame_size = i - lastJ;
            int8_t *result = [self Annex_BToAvcc:&videoData[lastJ] length:frame_size];
            [tool writeVideoFrame:result length:frame_size];
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
    int8_t *result = [resultData bytes];
    return data;
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
