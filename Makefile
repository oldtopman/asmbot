#.spp - aSsembly Pre-Processed

asmbot: asmbot.spp
	gcc <asmbot.spp -x assembler -nostdlib -static -o asmbot -arch i386 -

asmbot.spp: asmbot.s
	#clang -E asmbot.s -o asmbot.spp
	cpp -P -C asmbot.s | m4 > asmbot.spp

exit64: exit64.o
	ld exit64.o -e _main -o exit64 -macosx_version_min 10.13 -lSystem

exit64.o: exit64.spp
	as exit64.spp -o exit64.o

exit64.spp: exit64.s
	clang -E exit64.s -o exit64.spp
