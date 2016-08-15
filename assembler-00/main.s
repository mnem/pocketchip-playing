@---------------------------------------
@ Data section
@---------------------------------------
.data

.balign 4

@ typedef struct {
@     uint32_t * buffer;
@     int fd;
@     size_t screen_byte_size;
@     struct fb_fix_screeninfo fix_info;
@     struct fb_var_screeninfo var_info;
@ } screen_t;


screen: .word 4/*buffer*/ + 4/*fd*/ + 4/*screen_byte_size*/ + 68/*fix_info*/ + 160/*var_info*/





.balign 4
foo: .word 100
bar: .word 0

.balign 4
format: .asciz "\nI have the number %d\n\n"

.balign 4
screen_device: .asciz "/dev/fb0"

@ ---------------------------------------
@ Code section
@---------------------------------------
.text

@ Ensure code section is 4 byte aligned
.balign 4

open_fb:
    stmdb sp!, {r4, lr}

    ldr r0, screen_device_addr
    mov r1, #0x0002
    bl open

    mov r4, r0  @ r4 is the fd

    @ r0 contains the fd
    mov r1, #0x4600 @ FBIOGET_VSCREENINFO
    ldr r2, screen_addr
    add r2, #80
    bl ioctl @ ioctl(screen_fd, FBIOGET_VSCREENINFO, &var_info)

    mov r0, r4
    mov r1, #0x4600 @ FBIOGET_FSCREENINFO (0x4602)
    add r1, #0x2
    ldr r2, screen_addr
    add r2, #12
    bl ioctl @ ioctl(screen_fd, FBIOGET_FSCREENINFO, &fix_info)

    ldmia sp!, {r4, lr}
    bx lr


@ Make main visible so that gcc can link to it
.global main
 
@ Main entry point. Analogous to int main(int, char**) due to the way gcc links us
main:
    str lr, [sp, #-8]!   @ decrease sp by 8 byte then store lr in sp

    mov r0, #0
    mov r1, #1

loop:
    cmp r1, #230
    bgt end
    add r0, r0, r1
    add r1, r1, #1
    b loop
    
    @ ldr r1, foo_addr    @ Load the address of foo into r1
    @ ldr r1, [r1]        @ Load the contents of address into r1
    @ mov r2, #4
    @ add r0, r1, r2

    @ ldr r2, bar_addr
    @ str r0, [r2]

end:

    mov r1, r0              @ Number in param 2
    ldr r0, format_addr     @ Format in param 1
    bl printf               @ Call printf

    @ Exit with 0
    @ mov r0, #0
    bl open_fb

    @ Tidy up and leave
    ldr lr, [sp], #+8
    bx lr       @ Return from main

@ Data labels
foo_addr: .word foo
bar_addr: .word bar
format_addr: .word format
screen_addr: .word screen
screen_device_addr: .word screen_device

