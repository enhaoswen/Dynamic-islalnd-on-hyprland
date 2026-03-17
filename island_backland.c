#define _DEFAULT_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <glob.h>
#include <fcntl.h>

// ==========================================
// 1. CapsLock
// ==========================================
int get_capslock() {
    glob_t g; int on = 0; glob("/sys/class/leds/*capslock/brightness", 0, NULL, &g);
    for(size_t i = 0; i < g.gl_pathc; ++i) {
        FILE *f = fopen(g.gl_pathv[i], "r"); char v;
        if(f && fread(&v, 1, 1, f) == 1 && v == '1') on = 1;
        if(f) fclose(f); if(on) break;
    }
    globfree(&g); return on;
}

// ==========================================
// 2. 屏幕亮度
// ==========================================
void get_brightness(int *val, int *max) {
    glob_t g; *val = -1; *max = -1; glob("/sys/class/backlight/*/brightness", 0, NULL, &g);
    if(g.gl_pathc > 0) {
        FILE *f = fopen(g.gl_pathv[0], "r"); if(f) { fscanf(f, "%d", val); fclose(f); }
        char path[256]; snprintf(path, sizeof(path), "%s", g.gl_pathv[0]);
        char *last = strrchr(path, '/');
        if(last) {
            strcpy(last, "/max_brightness");
            FILE *fm = fopen(path, "r"); if(fm) { fscanf(fm, "%d", max); fclose(fm); }
        }
    }
    globfree(&g);
}

// ==========================================
// 3. 电量
// ==========================================
void get_battery(int *capacity, char *status) {
    *capacity = -1; status[0] = '\0'; glob_t g; glob("/sys/class/power_supply/BAT*", 0, NULL, &g);
    if(g.gl_pathc > 0) {
        char path[256];
        snprintf(path, sizeof(path), "%s/capacity", g.gl_pathv[0]);
        FILE *fc = fopen(path, "r"); if(fc) { fscanf(fc, "%d", capacity); fclose(fc); }
        snprintf(path, sizeof(path), "%s/status", g.gl_pathv[0]);
        FILE *fs = fopen(path, "r"); if(fs) { if(fgets(status, 32, fs)) status[strcspn(status, "\n")] = 0; fclose(fs); }
    }
    globfree(&g);
}

// ==========================================
// 4. Audio Info
// ==========================================
void get_audio_info(int *vol, int *mute, int *is_bt) {
    *vol = -1; *mute = 0; *is_bt = 0;
    FILE *f = popen("SINK=$(LC_ALL=C pactl get-default-sink 2>/dev/null); MUTE=$(LC_ALL=C pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null); VOL=$(LC_ALL=C pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null); echo \"$SINK|$MUTE|$VOL\"", "r");
    if (f) {
        char buf[512];
        if (fgets(buf, sizeof(buf), f)) {
            if (strstr(buf, "bluez_sink") || strstr(buf, "bluez_output")) *is_bt = 1;
            if (strstr(buf, "Mute: yes") || strstr(buf, "Mute: Yes")) *mute = 1;
            char *pct = strchr(buf, '%');
            if (pct) {
                *pct = '\0'; char *p = pct - 1;
                while (p >= buf && *p == ' ') p--;
                while (p >= buf && *p >= '0' && *p <= '9') p--;
                *vol = atoi(p + 1);
            }
        }
        pclose(f);
    }
}

// ==========================================
// Main Loop
// ==========================================
int main() {
    int last_caps = -1, last_bl_val = -1, last_bl_max = -1;
    int last_vol = -1, last_mute = -1, last_bt_sink = -1, last_bat_cap = -1;
    char last_bat_stat[32] = ""; int counter = 0, bt_cooldown = 0;

    setvbuf(stdout, NULL, _IONBF, 0);
    FILE *f_pw = popen("stdbuf -oL pw-mon", "r");
    if (f_pw) {
        int fd = fileno(f_pw); int flags = fcntl(fd, F_GETFL, 0);
        fcntl(fd, F_SETFL, flags | O_NONBLOCK);
    }
    
    get_audio_info(&last_vol, &last_mute, &last_bt_sink);

    while(1) {
        if (bt_cooldown > 0) bt_cooldown--;

        int caps = get_capslock();
        if (caps != last_caps) { if (last_caps != -1) printf("CAPS|%d\n", caps); last_caps = caps; }

        int bl_v, bl_m; get_brightness(&bl_v, &bl_m);
        if (bl_v != -1 && (bl_v != last_bl_val || bl_m != last_bl_max)) {
            if (last_bl_val != -1) printf("BL|%d|%d\n", bl_v, bl_m);
            last_bl_val = bl_v; last_bl_max = bl_m;
        }

        if (f_pw) {
            char pw_buf[256]; int audio_ev = 0;
            while (fgets(pw_buf, sizeof(pw_buf), f_pw)) if (strstr(pw_buf, "volume") || strstr(pw_buf, "mute") || strstr(pw_buf, "param-changed")) audio_ev = 1;
            if (audio_ev) {
                int vol, mute, is_bt; get_audio_info(&vol, &mute, &is_bt);
                if (vol != -1) {
                    if (last_bt_sink != -1 && is_bt != last_bt_sink) {
                        if (is_bt) printf("BT|CONN\n"); else printf("BT|DISCONN\n");
                        last_bt_sink = is_bt; bt_cooldown = 30; last_vol = vol; last_mute = mute;
                    } else if (vol != last_vol || mute != last_mute) {
                        if (last_vol != -1 && bt_cooldown == 0) { if (mute) printf("MUTE|%d\n", vol); else printf("VOL|%d\n", vol); }
                        last_vol = vol; last_mute = mute;
                    }
                }
            }
        }

        if (counter % 40 == 0) {
            int b_cap; char b_stat[32]; get_battery(&b_cap, b_stat);
            if (b_cap != -1 && (b_cap != last_bat_cap || strcmp(b_stat, last_bat_stat) != 0)) {
                if (last_bat_cap != -1) printf("BAT|%d|%s\n", b_cap, b_stat);
                last_bat_cap = b_cap; strcpy(last_bat_stat, b_stat);
            }
        }

        counter = (counter + 1) % 400; usleep(50000);
    }

    if (f_pw) pclose(f_pw);
    return 0;
}
