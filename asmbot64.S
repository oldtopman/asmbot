// Copyright (c) 2002 Sergey Lyubka
//
// Simple IRC bot in x64 assembly, written for MacOS.
// Compilation: See makefile
//
// To port to Linux, change syscall* macros.

//Ported to macOS 10.15 and 64 bit by oldtopman

//#include <sys/syscall.h>

//sysv calling convention:
// arguments rdi, rsi, rdx, rcx, r8, r9, then stack
// retvals rax, upper bits in rdx if necessary
// functions preserve rbx, rsp, rbp, r12, r13, r14, and r15
// functions can modify rax, rdi, rsi, rdx, rcx, r8, r9, r10, and r11

//osx syscall reference https://opensource.apple.com/source/xnu/xnu-6153.81.5/bsd/kern/syscalls.master.auto.html

//void exit(int rval);
.macro syscall_exit rval:req
	movq \rval, %rdi
	movq $0x2000001, %rax
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


.section __DATA,__data
debug_retval:	.quad	42
sock:		.long	0
logfd:		.long	0
usagestr:	.asciz	"usage:\nasmbot [server_ip [port]]\n"
fatalstr:	.asciz	"fatal error occured\n"
logfile:	.asciz	"asmbot.log"
tcp_nodelay:	.long	1

// the next few var is the sockaddr
sin_len:	.byte	16		// sizeof(sockaddr_in)
sin_family:	.byte	2		// AF_INET
sin_port:	.short	0x0b1a		// htons(6667)
in_addr:	.long	0x116813c3	// htonl(195.19.104.17), irc.tambov.ru
sin_addr:	.long	0xc3136811	// htonl(195.19.104.17), irc.tambov.ru

// IRC commands
cmd_user:	.asciz	"user asmbot asmbot asmbot asmbot\r\n"
cmd_nick:	.asciz	"nick asmbot\r\n"
cmd_join:	.asciz	"join #c\r\n"
cmd_pong:	.asciz	"PONG irc.tambov.ru\r\n"

.comm	ibuf,	512  // Maximum message length defined by IRC protocol
.comm	obuf,	512


// return string len. string ptr is pushed to stack
strlen:
	//pushl	%edi
	movl	8(%esp), %edi
	xorl	%eax, %eax
1:
	cmpb	$0, (%edi, %eax)
	jz	2f
	incl	%eax
	jmp	1b
2:
	//popl	%edi
	ret	$4
	
	
fatal:
	//pushl	%edx
	movl	8(%esp), %edx
	//pushl	%edx	
	call	strlen
	//SYSCALL(SYS_write, $1, %edx, %eax)
	//SYSCALL(SYS_exit, $1)	
	//popl	%edx
	ret
	

// Create socket, and connect it to a server. socket stored in the
// global variable sock
mksocket:
	//SYSCALL(SYS_socket, $2, $1, $0)  // socket(PF_INET, SOCK_STREAM, 0)
	//movl	%eax, sock
	//SYSCALL(SYS_connect, sock, $sin_len, $16)  // connect
	ret

// Open a log file and store a file descriptor in a global variable logfd
initlog:
	// open(logfile, O_WRONLY | O_APPEND | O_CREAT, 0644)
	//SYSCALL(SYS_open, $logfile, $(0x1 | 0x8 | 0x200), $0644)
	//movl	%eax, logfd
	ret

// Connect to the IRC server, join the channel
login:
	//pushl	$cmd_user
	call	strlen
	//SYSCALL(SYS_write, sock, $cmd_user, %eax);
	//pushl	$cmd_nick
	call	strlen
	//SYSCALL(SYS_write, sock, $cmd_nick, %eax);
	//SYSCALL(SYS_read, sock, $ibuf, $2048)
	//pushl	$cmd_join
	call	strlen
	//SYSCALL(SYS_write, sock, $cmd_join, %eax);
	ret

// Infinite main loop
loop:
2:
	//SYSCALL(SYS_read, sock, $ibuf, $2048)  // read(sock, ibuf, 2048)
	cmpl	$0, %eax
	jg	1f
	//pushl	$fatalstr
	call	fatal
	jmp	2b
1:
	// is it a server PING ?
	//cmpl	$0x474e4950, ibuf
	jne	3f
	// yes, send a response
	//pushl	$cmd_pong
	call	strlen
	//SYSCALL(SYS_write, sock, $cmd_pong, %eax);
	syscall_write sock(%rip), cmd_pong(%rip), %rax
	jmp	2b
3:
	syscall_write logfd(%rip), ibuf(%rip), %rax // write to logfile
	jmp	2b

// The entry point
.section __TEXT,__text
.globl _main
_main:
	syscall_exit debug_retval(%rip) //make sure we don't get bus errors before exiting
	//popl	%eax
	//popl	%eax
	//decl	%eax   // argc == 1 ?
	jz	1f
	
	// TODO: handle command-line arguments here
	
1:
	call	initlog
	call	mksocket
	call	login
	call	loop
