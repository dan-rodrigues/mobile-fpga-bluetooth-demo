ECP5_PACKAGE = CABGA381
ECP5_SIZE = 85

###

TOP = bluetooth_demo_top

ULX3S_PIN_DEF = ulx3s_v20.lpf

SOURCES := \
	$(TOP).v \
	pll.v \
	spi_led.v \
	debouncer.v

###

ulx3s: ulx3s.bit

ulx3s_prog: ulx3s.bit
	fujprog -j flash $<

###

%.json: $(SOURCES)
	yosys -p 'synth_ecp5 -top $(TOP) -json $@' $^

clean:
	rm -f ulx3s.config ulx3s.bit ulx3s.json

%.config: $(ULX3S_PIN_DEF) %.json
	nextpnr-ecp5 --package $(ECP5_PACKAGE) --$(ECP5_SIZE)k --json $(filter-out $<,$^) --placer heap --lpf $< --textcfg $@ --seed 0

%.bit: %.config
	ecppack --input $< --bit $@

.SECONDARY:
.PHONY: ulx3s_prog clean

