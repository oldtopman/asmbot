#.spp - aSsembly Pre-Processed

asmbot: asmbot.spp
	gcc <asmbot.spp -x assembler -nostdlib -static -o asmbot -arch i386 -

asmbot.spp: asmbot.s
	cpp -P -C asmbot.s | m4 > asmbot.spp

asmbot64: asmbot64.S
	clang asmbot64.S -o asmbot64 -Wall -Wextra
