//modified from http://www.idryman.org/blog/2014/12/02/writing-64-bit-assembly-on-mac-os-x/
//hello_asm.s
//as hello_asm.s -o hello_asm.o
//ld hello_asm.o -e _main -o hello_asm

#include <sys/syscall.h>
#define TEXT_STR "Hello World!\n"

.section __DATA,__data
str:
  .asciz TEXT_STR

.section __TEXT,__text
.globl _main
_main:
  movq $0x2000004, %rax           # preparing system call 4
  movq $1, %rdi                    # STDOUT file descriptor is 1
  movq str@GOTPCREL(%rip), %rsi   # The value to print
  movq $100, %rdx                 # the size of the value to print
  syscall

  movq $0, %rdi
  movq $0x2000001, %rax           # exit 0
  syscall
