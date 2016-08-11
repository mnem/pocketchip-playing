@---------------------------------------
@ Data section
@---------------------------------------
.data

.balign 4
foo:
    .word 100


@---------------------------------------
@ Code section
@---------------------------------------
.text

@ Ensure code section is 4 byte aligned
.balign 4

@ Make main visible so that gcc can link to it
.global main
 
@ Main entry point. Analogous to int main(int, char**) due to the way gcc links us
main:
    ldr r1, foo_addr    @ Load the address of foo into r1
    ldr r1, [r1]        @ Load the contents of address into r1
    mov r2, #4
    add r0, r1, r2
    bx lr       @ Return from main

@ Data labels
foo_addr: .word foo
