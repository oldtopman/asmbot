//connection tester

//sysv calling convention:
// arguments rdi, rsi, rdx, rcx, r8, r9, then stack
// retvals rax, upper bits in rdx if necessary
// functions preserve rbx, rsp, rbp, r12, r13, r14, and r15
// functions can modify rax, rdi, rsi, rdx, rcx, r8, r9, r10, and r11

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

// the next few var is the sockaddr
//struct sockaddr {
//	__uint8_t       sa_len;         /* total length */
//	sa_family_t     sa_family;      /* [XSI] address family */
//	char            sa_data[14];    /* [XSI] addr value (actually larger) */
//};

sin_len:	.byte	16		// sizeof(sockaddr_in)
sin_family:	.byte	2		// AF_INET
//sin_port:	.short	0x1092		// htons(4242)
//sin_addr:	.long	0xc0a8007b	// htonl(192.168.0.123)
sin_port:	.short	0x1010		// htons(4112)
sin_addr:	.long	0x010000ac	// htonl(172.0.0.1)
zero:		.quad	0		//zero...

// strings
greet_len:	.quad	12
greet_1:	.asciz	"greeting 1\r\n"
greet_2:	.asciz	"greeting 2\r\n"


.section __TEXT,__text

// Create socket, and connect it to a server. socket stored in the
// global variable sock
mksocket:

	//create socket, store in sock
	syscall_socket $2, $1, $0 //socket PF_INET, SOCK_STREAM, 0
	movq	%rax, sock(%rip)
	
	//connect with socket
	xor	%r9, %r9
	movb	sin_len(%rip), %r9b
	
	//put a pointer to the struct in the argument
	leaq	sin_len(%rip), %r10
	syscall_connect sock(%rip), %r10, %r9
	
	//put the struct in the argument
	//syscall_connect sock(%rip), sin_len(%rip), %r9 //struct directly
	
	//see if the connection worked
	or	%rax, %rax
	jz	1f
	
	//it didn't
	syscall_exit $1
1:
	//it did
	ret

// Open a log file and store a file descriptor in a global variable logfd
send_greetz:
	syscall_write $1, greet_1@GOTPCREL(%rip), greet_len(%rip) //stdout
	syscall_write sock(%rip), greet_1@GOTPCREL(%rip), greet_len(%rip) //socket
	
	syscall_write $1, greet_2@GOTPCREL(%rip), greet_len(%rip) //stdout
	syscall_write sock(%rip), greet_2@GOTPCREL(%rip), greet_len(%rip) //socket
	ret

// The entry point
.globl _main
_main:
	popq	%rax
	popq	%rax
	jz	1f //make sure argc is zero
	syscall_exit $2 //extra argument received, error
	
1:
	call	mksocket
	call	send_greetz
	syscall_exit $0
