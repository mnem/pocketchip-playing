@---------------------------------------
@ Some useful equatables
@---------------------------------------

.equ O_RDWR, 0x0002
.equ FBIOGET_VSCREENINFO, 0x4600 
.equ FBIOGET_FSCREENINFO, 0x4602
.equ FALSE, 0
.equ TRUE, 1

@---------------------------------------
@ Zero'd globals. These will be
@ allocated in the .bss section
@---------------------------------------

.lcomm screen_buffer, 4
.lcomm screen_fd, 4
.lcomm screen_byte_size, 4
.lcomm screen_fix_info, 68
.lcomm screen_var_info, 160

@---------------------------------------
@ Data section
@---------------------------------------
.data

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
    mov r1, #O_RDWR
    bl open
    cmp r0, #0
    bpl open_fb_device_opened
    b open_fb_fail_and_exit

open_fb_device_opened:
    @ Store the fd in r4 and also write to memory
    mov r4, r0
    ldr r1, screen_fd_addr
    str r0, [r1]

    @ Get the var info for the screen
    @ r0 already contains the fd
    mov r1, #FBIOGET_VSCREENINFO
    ldr r2, screen_var_info_addr
    bl ioctl @ ioctl(screen_fd, FBIOGET_VSCREENINFO, &var_info)
    cmp r0, #0
    bpl open_fb_got_var_info
    b open_fb_close_fd_and_fail_and_exit

open_fb_got_var_info:
    @ Get the fix info for the screen
    mov r0, r4
    ldr r1, =FBIOGET_FSCREENINFO    @ The value for FBIOGET_FSCREENINFO (0x4602)
                                    @ cannot be represented as a literal value, so
                                    @ use this pseudo-instruction which causes the
                                    @ compiler to stick the value in the contants
                                    @ pool which is then loaded into the register
    ldr r2, screen_fix_info_addr
    bl ioctl @ ioctl(screen_fd, FBIOGET_FSCREENINFO, &fix_info)
    cmp r0, #0
    bpl open_fb_got_fix_info
    b open_fb_close_fd_and_fail_and_exit

open_fb_got_fix_info:
    @ Work out the screen size
    ldr r0, screen_var_info_addr
    ldr r1, [r0, #4]    @ var_info.yres
    ldr r2, [r0, #24]   @ var_info.bpp
    ldr r0, [r0]        @ var_info.xres

    @ xres * yres * bpp / 8
    mul r0, r0, r1      @ n = xres * yres
    mul r0, r0, r2      @ n = n * bpp
    mov r1, r0, ASR #3  @ size = n >> 3 (i.e. / 8)

    @ Store the screen byte size
    ldr r0, screen_byte_size_addr
    str r1, [r0]

    @ Use mmap to access the screen buffer
    mov r6, #0 @ Handy NULL and zero

    @ Store sp so we can restore it after the call
    mov r5, sp @ Store sp in r5

    mov r0, r6      @ Param 1: NULL
    @ r1 contains screen_byte_size, param 2
    mov r2, #3      @ Param 3: PROT_READ | PROT_WRITE
    mov r3, #1      @ Param 4: MAP_SHARED
    @ The other params are passed through the stack in reverse order
    push {r4, r6}   @ Param 5, Param 6: fd, offset
    bl mmap @ mmap(NULL, screen_byte_size, PROT_READ | PROT_WRITE, MAP_SHARED, screen_fd, 0 /* offset */);

    @ restore the stack pointer
    mov sp, r5

    cmp r0, #0
    bpl open_fb_mmap_ok
    b open_fb_close_fd_and_fail_and_exit

open_fb_mmap_ok:
    @ Store the pointer to the screen buffer
    ldr r1, screen_buffer_addr
    str r0, [r1]

    mov r0, #TRUE
    b open_fb_exit

open_fb_close_fd_and_fail_and_exit:
    bl close_fb_fd

open_fb_fail_and_exit:
    mov r0, #FALSE

open_fb_exit:
    pop {r4, r5, r6, lr}
    bx lr

close_fb_fd:
    push {r4, lr}

    mov r4, #0  @ NULL/zero

    ldr r0, screen_fd_addr
    ldr r0, [r0]
    bl close @ close(*screen_fd_addr)
    ldr r0, screen_fd_addr
    str r4, [r0]

    mov r0, #TRUE
    pop {r4, lr}
    bx lr

close_fb:
    push {r4, lr}

    mov r4, #0  @ NULL/zero

    @ Unmap the memory
    ldr r0, screen_buffer_addr
    ldr r1, screen_byte_size_addr
    ldr r1, [r1]
    bl munmap @ munmap(screen_buffer_addr, *screen_byte_size_addr);
    ldr r0, screen_buffer_addr
    str r4, [r0]
    ldr r0, screen_byte_size_addr
    str r4, [r0]

    bl close_fb_fd

    mov r0, #TRUE
    pop {r4, lr}
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

    mov r0, #TRUE
    bx lr

@ Make main visible so that gcc can link to it
.global main
 
@ Main entry point. Analogous to int main(int, char**) due to the way gcc links us
main:
    @ Not using r4, but need to keep
    @ sp 8 byte aligned
    push {r4, lr}

    bl open_fb
    cmp r0, #FALSE
    movne r0, #1
    bne main_exit

    bl draw
    cmp r0, #FALSE
    movne r0, #2
    bne main_exit

    bl close_fb
    cmp r0, #FALSE
    movne r0, #3
    bne main_exit

    @ Exit with 0
    mov r0, #0

main_exit:
    pop {r4, lr}
    bx lr       @ Return from main

@ Data labels
screen_buffer_addr: .word screen_buffer
screen_fd_addr: .word screen_fd
screen_byte_size_addr: .word screen_byte_size
screen_fix_info_addr: .word screen_fix_info
screen_var_info_addr: .word screen_var_info
format_addr: .word format
screen_device_addr: .word screen_device
