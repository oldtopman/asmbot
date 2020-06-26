asmbot: asmbot.m4out
	gcc <asmbot.m4out -x assembler -nostdlib -static -o asmbot -arch i386 -

asmbot.m4out: asmbot.cppout
	m4 <asmbot.cppout >asmbot.m4out

asmbot.cppout: asmbot.s
	cpp -P -C asmbot.s > asmbot.cppout
