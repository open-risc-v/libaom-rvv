// libaom A/B 探针：AV1 编码 5 帧（128×96，AOM_Q，cpu-used=8，单线程）→ 解码回环。
// 哈希码流字节与解码 I420。
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <aom/aom_decoder.h>
#include <aom/aom_encoder.h>
#include <aom/aomcx.h>
#include <aom/aomdx.h>

#define W 128
#define H 96
#define NFRAMES 5

static void fill_i420(uint8_t *buf, int f)
{
    uint8_t *y = buf, *u = buf + W * H, *v = u + (W / 2) * (H / 2);
    for (int r = 0; r < H; r++)
        for (int c = 0; c < W; c++) {
            unsigned int n = (unsigned int)(c * 2654435761u + r * 40503u + f * 7919u);
            n ^= n >> 13;
            int val = (c * 2 + r + f * 3) & 0xff;
            if (((c >> 4) ^ (r >> 4)) & 1) val = 255 - val;
            val ^= (int)(n & 0x07);
            y[r * W + c] = (uint8_t)val;
        }
    for (int r = 0; r < H / 2; r++)
        for (int c = 0; c < W / 2; c++) {
            u[r * (W / 2) + c] = (uint8_t)((c * 3 + r + f) & 0xff);
            v[r * (W / 2) + c] = (uint8_t)((c + r * 5 + f * 2) & 0xff);
        }
}

int main(int argc, char **argv)
{
    const char *outp = argc > 1 ? argv[1] : NULL;
    aom_codec_ctx_t enc, dec;
    aom_codec_enc_cfg_t cfg;
    aom_codec_dec_cfg_t dcfg;
    if (aom_codec_enc_config_default(aom_codec_av1_cx(), &cfg, 0) != AOM_CODEC_OK) return 2;
    cfg.g_w = W; cfg.g_h = H;
    cfg.g_timebase.num = 1; cfg.g_timebase.den = 30;
    cfg.g_threads = 1;
    cfg.g_lag_in_frames = 0;
    cfg.rc_end_usage = AOM_Q;
    cfg.rc_min_quantizer = 30;
    cfg.rc_max_quantizer = 30;
    cfg.g_limit = NFRAMES;

    if (aom_codec_enc_init(&enc, aom_codec_av1_cx(), &cfg, 0) != AOM_CODEC_OK) {
        fprintf(stderr, "enc init: %s\n", aom_codec_error(&enc)); return 3;
    }
    aom_codec_control(&enc, AOME_SET_CPUUSED, 8);
    aom_codec_control(&enc, AV1E_SET_ROW_MT, 0);
    aom_codec_control(&enc, AV1E_SET_TILE_COLUMNS, 0);
    aom_codec_control(&enc, AV1E_SET_TILE_ROWS, 0);

    dcfg.threads = 1; dcfg.w = W; dcfg.h = H; dcfg.allow_lowbitdepth = 1;
    if (aom_codec_dec_init(&dec, aom_codec_av1_dx(), &dcfg, 0) != AOM_CODEC_OK) {
        fprintf(stderr, "dec init: %s\n", aom_codec_error(&dec)); return 4;
    }

    uint8_t *frame = malloc((size_t)W * H * 3 / 2);
    if (!frame) return 5;
    uint64_t hbits = 1469598103934665603ULL, hpix = 1469598103934665603ULL;
    unsigned long bytes = 0, dec_frames = 0;

    for (int f = 0; f < NFRAMES; f++) {
        fill_i420(frame, f);
        aom_image_t img;
        if (!aom_img_alloc(&img, AOM_IMG_FMT_I420, W, H, 1)) return 6;
        for (int r = 0; r < H; r++)
            memcpy(img.planes[AOM_PLANE_Y] + r * img.stride[AOM_PLANE_Y], frame + r * W, W);
        for (int p = 1; p < 3; p++) {
            const uint8_t *pl = frame + W * H + (p - 1) * (W / 2) * (H / 2);
            for (int r = 0; r < H / 2; r++)
                memcpy(img.planes[p] + r * img.stride[p], pl + r * (W / 2), W / 2);
        }
        if (aom_codec_encode(&enc, &img, f, 1, 0) != AOM_CODEC_OK) {
            fprintf(stderr, "encode: %s\n", aom_codec_error(&enc)); return 7;
        }
        const aom_codec_cx_pkt_t *pkt; aom_codec_iter_t it = NULL;
        while ((pkt = aom_codec_get_cx_data(&enc, &it)) != NULL) {
            if (pkt->kind != AOM_CODEC_CX_FRAME_PKT) continue;
            bytes += pkt->data.frame.sz;
            hbits = (hbits ^ pkt->data.frame.sz) * 1099511628211ULL;
            const uint8_t *b = (const uint8_t *)pkt->data.frame.buf;
            for (size_t i = 0; i < pkt->data.frame.sz; i++) { hbits ^= b[i]; hbits *= 1099511628211ULL; }
            if (aom_codec_decode(&dec, b, pkt->data.frame.sz, NULL) != AOM_CODEC_OK) {
                fprintf(stderr, "decode: %s\n", aom_codec_error(&dec)); return 8;
            }
            aom_image_t *out; aom_codec_iter_t dit = NULL;
            while ((out = aom_codec_get_frame(&dec, &dit)) != NULL) {
                dec_frames++;
                for (int p = 0; p < 3; p++) {
                    int pw = (p == 0) ? W : W / 2, ph = (p == 0) ? H : H / 2;
                    for (int r = 0; r < ph; r++) {
                        const uint8_t *row = out->planes[p] + r * out->stride[p];
                        for (int c = 0; c < pw; c++) { hpix ^= row[c]; hpix *= 1099511628211ULL; }
                    }
                }
            }
        }
        aom_img_free(&img);
    }

    char line[256];
    snprintf(line, sizeof line, "frames=%d bytes=%lu fnv_bit=%016llx dec_frames=%lu fnv_px=%016llx\n",
             NFRAMES, bytes, (unsigned long long)hbits, dec_frames, (unsigned long long)hpix);
    if (outp) { FILE *fp = fopen(outp, "wb"); if (fp) { fwrite(line, 1, strlen(line), fp); fclose(fp); } }
    fputs(line, stdout);
    aom_codec_destroy(&enc); aom_codec_destroy(&dec); free(frame);
    return dec_frames >= (unsigned long)NFRAMES ? 0 : 9;
}
