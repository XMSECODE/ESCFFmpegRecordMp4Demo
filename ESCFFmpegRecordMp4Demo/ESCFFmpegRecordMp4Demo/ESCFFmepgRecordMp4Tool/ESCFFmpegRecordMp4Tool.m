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


#define STREAM_DURATION   10.0
#define STREAM_FRAME_RATE 25 /* 25 images/s */
#define STREAM_PIX_FMT    AV_PIX_FMT_YUV420P /* default pix_fmt */

#define SCALE_FLAGS SWS_BICUBIC

// a wrapper around a single output AVStream
typedef struct OutputStream {
    AVStream *st;
    AVCodecContext *enc;
    
    /* pts of the next frame that will be generated */
    int64_t next_pts;
    int samples_count;
    
    AVFrame *frame;
    AVFrame *tmp_frame;
    
    float t, tincr, tincr2;
    
    struct SwsContext *sws_ctx;
    struct SwrContext *swr_ctx;
} OutputStream;

static void log_packet(const AVFormatContext *fmt_ctx, const AVPacket *pkt)
{
    AVRational *time_base = &fmt_ctx->streams[pkt->stream_index]->time_base;
    
    printf("pts:%s pts_time:%s dts:%s dts_time:%s duration:%s duration_time:%s stream_index:%d\n",
           av_ts2str(pkt->pts), av_ts2timestr(pkt->pts, time_base),
           av_ts2str(pkt->dts), av_ts2timestr(pkt->dts, time_base),
           av_ts2str(pkt->duration), av_ts2timestr(pkt->duration, time_base),
           pkt->stream_index);
}

/* Add an output stream. */
static void add_stream(OutputStream *ost, AVFormatContext *oc,
                       AVCodec **codec,
                       enum AVCodecID codec_id)
{
    AVCodecContext *c;
    int i;
    
    /* find the encoder */
    *codec = avcodec_find_encoder(codec_id);
    if (!(*codec)) {
        fprintf(stderr, "Could not find encoder for '%s'\n",
                avcodec_get_name(codec_id));
        exit(1);
    }
    
    ost->st = avformat_new_stream(oc, NULL);
    if (!ost->st) {
        fprintf(stderr, "Could not allocate stream\n");
        exit(1);
    }
    ost->st->id = oc->nb_streams-1;
    c = avcodec_alloc_context3(*codec);
    if (!c) {
        fprintf(stderr, "Could not alloc an encoding context\n");
        exit(1);
    }
    ost->enc = c;
    
    switch ((*codec)->type) {
        case AVMEDIA_TYPE_AUDIO:
            c->sample_fmt  = (*codec)->sample_fmts ?
            (*codec)->sample_fmts[0] : AV_SAMPLE_FMT_FLTP;
            c->bit_rate    = 64000;
            c->sample_rate = 44100;
            if ((*codec)->supported_samplerates) {
                c->sample_rate = (*codec)->supported_samplerates[0];
                for (i = 0; (*codec)->supported_samplerates[i]; i++) {
                    if ((*codec)->supported_samplerates[i] == 44100)
                        c->sample_rate = 44100;
                }
            }
            c->channels        = av_get_channel_layout_nb_channels(c->channel_layout);
            c->channel_layout = AV_CH_LAYOUT_STEREO;
            if ((*codec)->channel_layouts) {
                c->channel_layout = (*codec)->channel_layouts[0];
                for (i = 0; (*codec)->channel_layouts[i]; i++) {
                    if ((*codec)->channel_layouts[i] == AV_CH_LAYOUT_STEREO)
                        c->channel_layout = AV_CH_LAYOUT_STEREO;
                }
            }
            c->channels        = av_get_channel_layout_nb_channels(c->channel_layout);
            ost->st->time_base = (AVRational){ 1, c->sample_rate };
            break;
            
        case AVMEDIA_TYPE_VIDEO:
            c->codec_id = codec_id;
            
            c->bit_rate = 400000;
            /* Resolution must be a multiple of two. */
            c->width    = 352;
            c->height   = 288;
            /* timebase: This is the fundamental unit of time (in seconds) in terms
             * of which frame timestamps are represented. For fixed-fps content,
             * timebase should be 1/framerate and timestamp increments should be
             * identical to 1. */
            ost->st->time_base = (AVRational){ 1, STREAM_FRAME_RATE };
            c->time_base       = ost->st->time_base;
            
            c->gop_size      = 12; /* emit one intra frame every twelve frames at most */
            c->pix_fmt       = STREAM_PIX_FMT;
            if (c->codec_id == AV_CODEC_ID_MPEG2VIDEO) {
                /* just for testing, we also add B-frames */
                c->max_b_frames = 2;
            }
            if (c->codec_id == AV_CODEC_ID_MPEG1VIDEO) {
                /* Needed to avoid using macroblocks in which some coeffs overflow.
                 * This does not happen with normal video, it just happens here as
                 * the motion of the chroma plane does not match the luma plane. */
                c->mb_decision = 2;
            }
            break;
            
        default:
            break;
    }
    
    /* Some formats want stream headers to be separate. */
    if (oc->oformat->flags & AVFMT_GLOBALHEADER)
        c->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
}

/**************************************************************/
/* audio output */

static AVFrame *alloc_audio_frame(enum AVSampleFormat sample_fmt,
                                  uint64_t channel_layout,
                                  int sample_rate, int nb_samples)
{
    AVFrame *frame = av_frame_alloc();
    int ret;
    
    if (!frame) {
        fprintf(stderr, "Error allocating an audio frame\n");
        exit(1);
    }
    
    frame->format = sample_fmt;
    frame->channel_layout = channel_layout;
    frame->sample_rate = sample_rate;
    frame->nb_samples = nb_samples;
    
    if (nb_samples) {
        ret = av_frame_get_buffer(frame, 0);
        if (ret < 0) {
            fprintf(stderr, "Error allocating an audio buffer\n");
            exit(1);
        }
    }
    
    return frame;
}

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

    if (ret < 0) {
        printf("alloc failed!");
        return nil;
    }
    
    if (codecType == ESCVideoCodecTypeH264) {
        formatContext->video_codec_id = AV_CODEC_ID_H264;
    }else if(codecType == ESCVideoCodecTypeH265) {
        formatContext->video_codec_id = AV_CODEC_ID_H265;
    }
    
    AVStream *o_video_stream = avformat_new_stream(formatContext, NULL);
    
    o_video_stream->time_base = (AVRational){ 1, videoFrameRate };
    record.video_baseTime = o_video_stream->time_base;
    
        
    AVCodecParameters *parameters = o_video_stream->codecpar;
    parameters->bit_rate = 1200000;
    parameters->codec_type = AVMEDIA_TYPE_VIDEO;
    parameters->codec_id = formatContext->video_codec_id;
    parameters->width = videoWidth;
    parameters->height = videoHeight;
//    parameters->format = AV_PIX_FMT_YUVJ420P;
    
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
    
    AVStream *o_video_stream = avformat_new_stream(formatContext, NULL);
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
    //    parameters->format = AV_PIX_FMT_YUVJ420P;
    
    /*====================================audio stream===================================================================================================*/
    AVStream *out_audio_stream = avformat_new_stream(formatContext, NULL);
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
    audioParameters->codec_id = AV_CODEC_ID_PCM_S16LE;
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
    
    ret = avformat_write_header(formatContext, NULL);
    if (ret < 0) {
        printf("write header failed!");
        return nil;
    }
    
    record.formatContext = formatContext;
    record.o_video_stream = o_video_stream;
    record.out_audio_stream = out_audio_stream;
    return record;
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
    
    self.a_dts++;
    self.a_pts++;
    pkt.dts = self.a_dts;
    pkt.pts = self.a_pts;
    
//    ret = write_frame(oc, &c->time_base, ost->st, &pkt);
    ret = [self writeFrame:_formatContext time_base:&_audio_baseTime stream:_out_audio_stream packet:&pkt];
    if (ret < 0) {
        fprintf(stderr, "Error while writing audio frame: %s\n",
                av_err2str(ret));
//        exit(1);
        return;
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

+ (void)H264RecordToMP4WithH264FilePath:(NSString *)h264FilePath
                            aacFilePath:(NSString *)aacFilePath
                            mp4FilePath:(NSString *)mp4FilePath
                             videoWidth:(int)videoWidth
                            videoHeight:(int)videoHeight
                         videoFrameRate:(int)videoFrameRate {
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
                                              audioSampleRate:8000
                                           audioChannelLayout:0
                                                audioChannels:1];
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

@end
