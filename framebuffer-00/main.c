/**
 * Some hacked together code which opens the framebuffer device on a
 * PocketCHIP and draws a short line. Woo.
 *
 * The code works but may be a bit rubbish-y as it's been many years since
 * I've done this sort of thing. The code requires (and checks) that the
 * framebuffer is 32 bits per pixel as that lets me cheat and make many
 * assumptions. This is true when I wrote this code, but who knows what
 * future updates for the PocketCHIP will do?
 *
 *
 * Copyright © 2016 David Wagner. See LICENSE in repo root.
 *
 */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
#include <linux/fb.h>
#include <sys/ioctl.h>

// Simple structure to hold details about the framebuffer device after it has
// been opened.
typedef struct {
	// Pointer to the pixels. Try to not write off the end of it.
	uint32_t * buffer;
	// The file descriptor for the device.
	int fd;
	// Number of bytes in the buffer. To work out how many elements are in the buffer, divide this by 4 (i.e. sizeof(uint32_t))
	size_t screen_byte_size;
	// Structs providing further information about the buffer configuration. See https://www.kernel.org/doc/Documentation/fb/api.txt
	struct fb_fix_screeninfo fix_info;
	struct fb_var_screeninfo var_info;
} screen_t;

// Because you can't have too many variants of NULL
static const screen_t NULL_SCREEN = {0};

// Indicates if the passed screen_t struct is valid.
#define valid_screen(s) ((s).buffer != NULL)

/**
 * Opens the first frame buffer device and returns a screen_t struct
 * for accessing it. If the framebuffer isn't in the expected format
 * (32 bits per pixel), NULL_SCREEN will be returned.
 */
screen_t open_fb() {
	const char * const SCREEN_DEVICE = "/dev/fb0";
	int screen_fd = open(SCREEN_DEVICE, O_RDWR);
	if (screen_fd == -1) {
		printf("ERROR: Failed to open %s\n", SCREEN_DEVICE);
		return NULL_SCREEN;
	}

	struct fb_var_screeninfo var_info = {0};
	if (ioctl(screen_fd, FBIOGET_VSCREENINFO, &var_info) == -1) {
		printf("ERROR: Failed to get variable screen info\n");
		return NULL_SCREEN;
	}

	struct fb_fix_screeninfo fix_info = {0};
	if (ioctl(screen_fd, FBIOGET_FSCREENINFO, &fix_info) == -1) {
		printf("ERROR: Failed to get fixed screen info\n");
		return NULL_SCREEN;
	}

	if (var_info.bits_per_pixel != 32) {
		printf("ERROR: Only support 32 bits per pixel. Detected bits per pixel: %d\n", var_info.bits_per_pixel);
		return NULL_SCREEN;
	}

	const size_t screen_byte_size = var_info.xres * var_info.yres * var_info.bits_per_pixel / 8;
	uint32_t * const buffer = (uint32_t *)mmap(NULL, screen_byte_size, PROT_READ | PROT_WRITE, MAP_SHARED, screen_fd, 0 /* offset */);

	screen_t screen = {
		.buffer = buffer,
		.fd = screen_fd,
		.screen_byte_size = screen_byte_size,
		.fix_info = fix_info,
		.var_info = var_info
	};
	return screen;
}

/**
 * Closes the framebuffer when you are finished with it. Don't try
 * to access things in the struct after calling this or else a
 * kitten will die.
 */
void close_fb(screen_t *screen) {
	munmap(screen->buffer, screen->screen_byte_size);
	close(screen->fd);
	*screen = NULL_SCREEN;
}

/**
 * Draws 100 purple pixels to the PocketCHIP's screen. Awesome, huh?
 */
void draw(screen_t * const screen) {
	for (int i = 0; i < 100; ++i) {
		screen->buffer[i] = 0x00ff00ff;
	}
}

/**
 * Main entry point. Opens the screen device, draws a line and then
 * exits. What more could a person want?
 */
int main(int argc, char** argv) {
	screen_t screen = open_fb();
	if (!valid_screen(screen)) {
		printf("ERROR: Failed to open screen\n");
		return 1;
	}

	draw(&screen);

	printf("All done, bye bye.\n");
	close_fb(&screen);
	return 0;
}
