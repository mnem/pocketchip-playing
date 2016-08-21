/**
 * Some hacked together code which opens the framebuffer device on a
 * PocketCHIP and draws a short line. But this time in assembler.
 *
 * See framebuffer-00 in the repo for the c code that this was
 * originally written in.
 *
 * Copyright © 2016 David Wagner. See LICENSE in repo root.
 *
 */

@---------------------------------------
@ Some useful equatables
@---------------------------------------

.equ O_RDWR, 0x0002
.equ FBIOGET_VSCREENINFO, 0x4600 
.equ FBIOGET_FSCREENINFO, 0x4602
.equ FALSE, 0
.equ TRUE, 1
.equ FAILED, -1
.equ NUL, 0

.equ REQUIRED_BPP, 32

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

screen_device: .asciz "/dev/fb0"

emsg_could_not_open_device: .asciz "ERROR: Failed to open %s\n"
emsg_could_not_get_var_info: .asciz "ERROR: Failed to get variable screen info\n"
emsg_could_not_get_fix_info: .asciz "ERROR: Failed to get fixed screen info\n"
emsg_could_not_mmap_buffer: .asciz "ERROR: Failed to get mmap screeb buffer\n"
emsg_unexpected_bpp: .asciz "ERROR: Only support %d bits per pixel. Detected bits per pixel: %d\n"

msg_screen_info: .asciz "xres: %d, yres: %d, bpp: %d\n"

@ ---------------------------------------
@ Code section
@---------------------------------------
.text

@ Ensure code section is 4 byte aligned
.balign 4

@ Function: open_screen
@
@ Opens the framebuffer device and mmaps
@ it's display memory
@
@ Returns: TRUE if successful, FALSE if 
@          something goes wrong
open_screen:
    push {r4, r5, r6, lr}

    @ Try opening the device
    ldr r0, =screen_device      @ Param 1: Pointer to the string containing the device path
    mov r1, #O_RDWR             @ Param 2: Mode to open the device in
    bl open

    @ Check the result
    cmp r0, #FAILED
    bne .Lopen_screen_device_opened     @ If not failed, branch to continue

    @ Show error and exit
    ldr r0, =emsg_could_not_open_device
    ldr r1, =screen_device
    bl printf
    b .Lopen_screen_fail_and_exit

.Lopen_screen_device_opened:
    @ Move the fd value to r4 and also store to memory
    mov r4, r0
    ldr r1, =screen_fd  @ r1 = &screen_fd
    str r0, [r1]        @ *r1 = r0

    @ Get the var info for the screen
    @ Param 1: r0 already contains the fd
    mov r1, #FBIOGET_VSCREENINFO    @ Param 2: Request
    ldr r2, =screen_var_info        @ Param 3: &screen_var_info
    bl ioctl @ ioctl(screen_fd, FBIOGET_VSCREENINFO, &var_info)

    @ Check the result
    cmp r0, #FAILED
    bne .Lopen_screen_got_var_info      @ If not failed, branch to continue

    @ Show error and exit
    ldr r0, =emsg_could_not_get_var_info
    bl printf
    b .Lopen_screen_close_fd_and_fail_and_exit

.Lopen_screen_got_var_info:
    @ Get the fix info for the screen
    mov r0, r4  @ Param 1: screen_fd
    ldr r1, =FBIOGET_FSCREENINFO    @ Param 2: Request
                                    @ The value for FBIOGET_FSCREENINFO (0x4602)
                                    @ cannot be represented as a literal value, so
                                    @ use this pseudo-instruction which causes the
                                    @ compiler to stick the value in the constants
                                    @ pool which is then loaded into the register
    ldr r2, =screen_fix_info    @ Param 3: &screen_fix_info
    bl ioctl @ ioctl(screen_fd, FBIOGET_FSCREENINFO, &fix_info)

    @ Check the result
    cmp r0, #FAILED
    bne .Lopen_screen_got_fix_info      @ If not failed, branch to continue

    @ Show error and exit
    ldr r0, =emsg_could_not_get_fix_info
    bl printf
    b .Lopen_screen_close_fd_and_fail_and_exit

.Lopen_screen_got_fix_info:
    @ Work out the screen size
    ldr r3, =screen_var_info
    ldr r2, [r3, #24]   @ var_info.bpp

    @ Check that we're running in the correct depth
    cmp r2, #REQUIRED_BPP
    beq .Lopen_screen_mmap_screen   @ If we are, branch to continue

    @ Show error and exit
    ldr r0, =emsg_unexpected_bpp
    mov r1, #REQUIRED_BPP
    mov r2, r5
    bl printf
    b .Lopen_screen_close_fd_and_fail_and_exit

.Lopen_screen_mmap_screen:
    ldr r0, [r3]        @ var_info.xres
    ldr r1, [r3, #4]    @ var_info.yres

    @ xres * yres * bpp / 8
    mul r6, r0, r1      @ n = xres * yres
    mul r6, r6, r2      @ n = n * bpp
    mov r6, r6, ASR #3  @ size = n >> 3 (i.e. / 8)

    @ Store the screen byte size to memory
    ldr r3, =screen_byte_size
    str r6, [r3]

    @ Show some handy informative output
    mov r3, r2
    mov r2, r1
    mov r1, r0
    ldr r0, =msg_screen_info
    bl printf

    @ Use mmap to access the screen buffer
    mov r0, #NUL    @ Param 1: NULL
    mov r1, r6      @ Param 2: screen_byte_size
    mov r2, #3      @ Param 3: PROT_READ | PROT_WRITE
    mov r3, #1      @ Param 4: MAP_SHARED
    @ The remaining params are passed through the stack in reverse order
    mov r5, sp @ Store sp in r5 @ Store sp so we can restore it after the call
    mov r6, #0
    push {r4, r6}   @ Param 5, Param 6: fd, offset
    bl mmap @ mmap(NULL, screen_byte_size, PROT_READ | PROT_WRITE, MAP_SHARED, screen_fd, 0 /* offset */);
    @ restore the stack pointer
    mov sp, r5

    @ Check the result
    cmp r0, #FAILED
    bne .Lopen_screen_mmap_ok   @ If not failed, branch to continue

    @ Show error and exit
    ldr r0, =emsg_could_not_mmap_buffer
    bl printf
    b .Lopen_screen_close_fd_and_fail_and_exit

.Lopen_screen_mmap_ok:
    @ Store the pointer to the screen buffer to memory
    ldr r1, =screen_buffer
    str r0, [r1]

    @ Exit with success
    mov r0, #TRUE
    b .Lopen_screen_exit

.Lopen_screen_close_fd_and_fail_and_exit:
    bl close_screen_fd

.Lopen_screen_fail_and_exit:
    @ Exit with failure
    mov r0, #FALSE

.Lopen_screen_exit:
    pop {r4, r5, r6, lr}
    bx lr

@ Function: close_screen_fd
@
@ Closes the previously opened framebuffer
@ device fd
@
@ Returns: TRUE if successful, FALSE if 
@          something goes wrong
close_screen_fd:
    push {r4, lr}

    mov r4, #0  @ NULL/zero

    ldr r0, =screen_fd
    ldr r0, [r0]
    bl close @ close(*=screen_fd)
    ldr r0, =screen_fd
    str r4, [r0]

    mov r0, #TRUE
    pop {r4, lr}
    bx lr

@ Function: close_screen
@
@ Releases all retained resources.
@
@ Returns: TRUE if successful, FALSE if 
@          something goes wrong
close_screen:
    push {r4, lr}

    mov r4, #0  @ NULL/zero

    @ Unmap the memory
    ldr r0, =screen_buffer
    ldr r1, =screen_byte_size
    ldr r1, [r1]
    bl munmap @ munmap(&screen_buffer, *=screen_byte_size);
    ldr r0, =screen_buffer
    str r4, [r0]
    ldr r0, =screen_byte_size
    str r4, [r0]

    bl close_screen_fd

    mov r0, #TRUE
    pop {r4, lr}
    bx lr

@ Function: draw
@
@ Draws something on the open screen
@
@ Returns: TRUE if successful, FALSE if 
@          something goes wrong
draw:
    @ Not using anything above r3 and no other function
    @ calls, so we don't need to store lr or adjust sp
    mov r0, #99 @ 100 pixel line shall be drawn
    mov r1, #0xff0000 @ Lo, it shall be a red pixel
    ldr r2, =screen_buffer
    ldr r2, [r2]
.Ldraw_plot:
    str r1, [r2, r0, LSL #2] @ Stick the red pixel at buffer + r0 * 4 (because pixels are 4 bytes)
    subs r0, #1
    bpl .Ldraw_plot

    mov r0, #TRUE
    bx lr

@ Make main visible so that gcc can link to it
.global main
 
@ Function: main
@
@ Main entry point as we're linking as a c
@ program.
@
@ Params:
@   r0: argc
@   r1: argv
@
@ Returns: TRUE if successful, FALSE if 
@          something goes wrong
main:
    @ Not using r4, but need to keep
    @ sp 8 byte aligned
    push {r4, lr}

    bl open_screen
    cmp r0, #TRUE
    bne .Lmain_exit_with_error @ If not successful, exit

    bl draw
    cmp r0, #TRUE
    bne .Lmain_exit_with_error @ If not successful, exit

    bl close_screen
    cmp r0, #TRUE
    bne .Lmain_exit_with_error @ If not successful, exit

    @ Exit with 0
    mov r0, #0
    b .Lmain_exit

.Lmain_exit_with_error:
    mov r0, #1

.Lmain_exit:
    pop {r4, lr}
    bx lr       @ Return from main
