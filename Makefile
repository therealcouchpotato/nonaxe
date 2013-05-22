MIPS_FPC=ppcrossmips
MIPS_FPC_OPTS=-dMIPS -B -Mdelphi -XX -Xr. -XS

ARM_FPC=ppcrossarm
ARM_FPC_OPTS=-Mdelphi -XX -Xr. -XS

FPC=fpc
FPC_OPTS=-Mdelphi -XX -XS

native:
	$(FPC) $(FPC_OPTS) nonaxe.pas
mips:
	$(MIPS_FPC) $(MIPS_FPC_OPTS) nonaxe.pas
arm:
	$(ARM_FPC) $(ARM_FPC_OPTS) nonaxe.pas
clean:
	@-rm *.o *.ppu link.res nonaxe
help:
	@-printf "make native (= make)\n\
make mips\n\
make arm\n\
make clean\n"