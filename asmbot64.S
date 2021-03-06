// Original version Copyright (c) 2002 Sergey Lyubka
// 64-bit update changes Copyright (c) 2020 oldtopman
// Simple IRC bot in x64 assembly, written for MacOS.
// Compilation: See makefile
//
// To port to Linux, change syscall* macros.


//sysv calling convention:
// arguments rdi, rsi, rdx, rcx, r8, r9, then stack
// retvals rax, upper bits in rdx if necessary
// functions preserve rbx, rsp, rbp, r12, r13, r14, and r15
// functions can modify rax, rdi, rsi, rdx, rcx, r8, r9, r10, and r11

//macOS syscall reference https://opensource.apple.com/source/xnu/xnu-6153.81.5/bsd/kern/syscalls.master.auto.html

//void exit(int rval);
.macro syscall_exit rval:req
	movq \rval, %rdi
	movq $0x2000001, %rax
	syscall
.endm

//user_ssize_t read(int fd, user_addr_t cbuf, user_size_t nbyte)
.macro syscall_read fd:req cbuf:req nbyte:req
	movq \fd, %rdi
	movq \cbuf, %rsi
	movq \nbyte, %rdx
	movq $0x2000003, %rax
	syscall
.endm

//user_ssize_t write(int fd, user_addr_t cbuf, user_size_t nbyte);
.macro syscall_write fd:req cbuf:req nbyte:req
	movq \fd, %rdi
	movq \cbuf, %rsi
	movq \nbyte, %rdx
	movq $0x2000004, %rax
	syscall
.endm

//int open(user_addr_t path, int flags, int mode)
.macro syscall_open path:req flags:req mode:req
	movq \path, %rdi
	movq \flags, %rsi
	movq \mode, %rdx
	movq $0x2000005, %rax
	syscall
.endm

//int socket(int domain, int type, int protocol)
.macro syscall_socket domain:req type:req protocol:req
	movq \domain, %rdi
	movq \type, %rsi
	movq \protocol, %rdx
	movq $0x2000061, %rax
	syscall
.endm

//int connect(int s, caddr_t name, socklen_t namelen)
.macro syscall_connect s:req name:req namelen:req
	movq \s, %rdi
	movq \name, %rsi
	movq \namelen, %rdx
	movq $0x2000062, %rax
	syscall
.endm

.section __DATA,__data
sock:		.quad	0
logfd:		.quad	0
usagestr:	.asciz	"usage:\nasmbot\n"
fatalstr:	.asciz	"fatal error occured\n"
logfile:	.asciz	"asmbot64.log\0"
//tcp_nodelay:	.quad	1

//sockaddr_in
sin_len:	.byte	16		// sizeof(sockaddr_in)
sin_family:	.byte	2		// AF_INET
sin_port:	.short	0x5a1e		// htons(7770)
//sin_addr:	.long	0x0ec685c3	// htonl(195.133.198.14) irc.tambov.ru
sin_addr:	.long	0x0100007f	// htonl(127.0.0.1)
sin_zero:	.quad	0		//zero...

// IRC commands
cmd_user:	.asciz	"user asmbot64 asmbot64 asmbot64 asmbot64\r\n"
cmd_nick:	.asciz	"nick asmbot64\r\n"
cmd_join:	.asciz	"join #c\r\n"
cmd_pong:	.asciz	"PONG irc.tambov.ru\r\n"

.comm	ibuf,	512  // Maximum message length defined by IRC protocol

.section __TEXT,__text

// return string len. string ptr is pushed to stack
strlen:
	pushq	%rdi
	movq	16(%rsp), %rdi
	xorq	%rax, %rax
1:
	cmpb	$0, (%rdi, %rax)
	jz	2f
	incq	%rax
	jmp	1b
2:
	popq	%rdi
	ret	$4
	
	
fatal:
	pushq	%rdx
	movq	16(%rsp), %rdx
	pushq	%rdx
	call	strlen
	syscall_write $1, %rdx, %rax
	syscall_exit $1
	popq	%rdx
	ret

// Create socket, and connect it to a server. socket stored in the
// global variable sock
mksocket:
	syscall_socket $2, $1, $0 //socket PF_INET, SOCK_STREAM, 0
	movq	%rax, sock(%rip)
	syscall_connect sock(%rip), sin_len@GOTPCREL(%rip), $16
	or	%rax, %rax
	jz	1f
	syscall_exit $2
1:
	ret

// Open a log file and store a file descriptor in a global variable logfd
initlog:
	// open(logfile, O_WRONLY | O_APPEND | O_CREAT, 0644)
	syscall_open logfile@GOTPCREL(%rip), $(0x1 | 0x8 | 0x200), $0644
	movq	%rax, logfd(%rip)
	ret

// Connect to the IRC server, join the channel
irc_login:
	pushq	cmd_user@GOTPCREL(%rip)
	call	strlen
	syscall_write sock(%rip), cmd_user@GOTPCREL(%rip), %rax
	addq	$4, %rsp
	
	pushq	cmd_nick@GOTPCREL(%rip)
	call	strlen
	syscall_write sock(%rip), cmd_nick@GOTPCREL(%rip), %rax
	addq	$4, %rsp
	
	syscall_read sock(%rip), ibuf@GOTPCREL(%rip), $512
	
	pushq	cmd_join@GOTPCREL(%rip)
	call	strlen
	syscall_write sock(%rip), cmd_join@GOTPCREL(%rip), %rax
	addq	$4, %rsp
	ret

// Infinite main loop
irc_loop:
2:
	syscall_read sock(%rip), ibuf@GOTPCREL(%rip), $512 //read sock, ibuf, 2048
	cmpq	$0, %rax
	jg	1f
	pushq	fatalstr@GOTPCREL(%rip)
	call	fatal
	jmp	2b
1:
	// is it a server PING ?
	cmpl	$0x474e4950, ibuf(%rip)
	jne	3f
	// yes, send a response
	pushq	cmd_pong@GOTPCREL(%rip)
	call	strlen
	syscall_write sock(%rip), cmd_pong@GOTPCREL(%rip), %rax
	jmp	2b
3:
	syscall_write logfd(%rip), ibuf@GOTPCREL(%rip), %rax // write to logfile
	jmp	2b

// The entry point
.globl _main
_main:
	popq	%rax
	popq	%rax
	jz	1f //make sure argc is zero
	syscall_exit $2 //extra argument received, error
	
	// TODO: handle command-line arguments here
	
1:
	call	initlog
	call	mksocket
	call	irc_login
	call	irc_loop
