@---------------------------------------
@ Data section
@---------------------------------------
.data

.balign 4

screen_buffer: .word 0
screen_fd: .word 0
screen_byte_size: .word 0
screen_fix_info: .skip 68
screen_var_info: .skip 160

.balign 4
format: .asciz "\nI have the number 0x%x\n\n"

.balign 4
screen_device: .asciz "/dev/fb0"

@ ---------------------------------------
@ Code section
@---------------------------------------
.text

@ Ensure code section is 4 byte aligned
.balign 4

open_fb:
    push {r4, r5, r6, lr}

    ldr r0, screen_device_addr
    mov r1, #0x0002 @ O_RDWR
    bl open

    @ Store the fd in r4 and also write to memory
    mov r4, r0
    ldr r1, screen_fd_addr
    str r0, [r1]

    @ r0 contains the fd
    mov r1, #0x4600 @ FBIOGET_VSCREENINFO
    ldr r2, screen_var_info_addr
    bl ioctl @ ioctl(screen_fd, FBIOGET_VSCREENINFO, &var_info)

    mov r0, r4
    ldr r1, =0x4602 @ FBIOGET_FSCREENINFO (0x4602)
    ldr r2, screen_fix_info_addr
    bl ioctl @ ioctl(screen_fd, FBIOGET_FSCREENINFO, &fix_info)

@ const size_t screen_byte_size = var_info.xres * var_info.yres * var_info.bits_per_pixel / 8;
@ uint32_t * const buffer = (uint32_t *)mmap(NULL, screen_byte_size, PROT_READ | PROT_WRITE, MAP_SHARED, screen_fd, 0 /* offset */);

    @ xres: 0
    @ yres: 4
    @ bpp: 24

    @ size_t screen_byte_size = var_info.xres * var_info.yres * var_info.bits_per_pixel / 8;
    ldr r0, screen_var_info_addr
    ldr r1, [r0, #4] @ yres
    ldr r2, [r0, #24] @ bpp
    ldr r0, [r0] @ xres

    @ xres * yres * bpp / 8
    mul r0, r0, r1
    mul r0, r0, r2
    mov r1, r0, ASR #3

    @ int32_t * buffer = (uint32_t *)mmap(NULL, screen_byte_size, PROT_READ | PROT_WRITE, MAP_SHARED, screen_fd, 0 /* offset */);
    mov r6, #0 @ Handy NULL

    mov r5, sp @ Store sp in r5
    mov r0, r6 @ Param 1: NULL
    @ r1 contains screen_byte_size, param 2
    mov r2, #3 @ Param 3: PROT_READ | PROT_WRITE
    mov r3, #1 @ Param 4: MAP_SHARED
    @ The other params are passed through the stack in reverse order
    push {r6} @ Param 6: 0, offset
    push {r4} @ Param 5: fd
    bl mmap

    @ restore the stack pointer
    mov sp, r5

    @ Store the pointer to the screen buffer
    ldr r1, screen_buffer_addr
    str r0, [r1]

    pop {r4, r5, r6, lr}
    bx lr

draw:
    @ Not using anything above r3 and no other function
    @ calls, so we don't need to store lr or adjust sp
    mov r0, #99 @ 100 pixel line shall be drawn
    mov r1, #0xff0000 @ Lo, it shall be a red pixel
    ldr r2, screen_buffer_addr
    ldr r2, [r2]
draw_plot:
    str r1, [r2, r0, LSL #2] @ Stick the red pixel at buffer + r0 * 4 (because pixels are 4 bytes)
    subs r0, #1
    bpl draw_plot

    bx lr

@ Make main visible so that gcc can link to it
.global main
 
@ Main entry point. Analogous to int main(int, char**) due to the way gcc links us
main:
    push {lr}

    bl open_fb
    bl draw

    mov r1, r0              @ Number in param 2
    ldr r0, format_addr     @ Format in param 1
    bl printf               @ Call printf

    @ Exit with 0
    mov r0, #0

    pop {lr}
    bx lr       @ Return from main

@ Data labels
screen_buffer_addr: .word screen_buffer
screen_fd_addr: .word screen_fd
screen_byte_size_addr: .word screen_byte_size
screen_fix_info_addr: .word screen_fix_info
screen_var_info_addr: .word screen_var_info
format_addr: .word format
screen_device_addr: .word screen_device
