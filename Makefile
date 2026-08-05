.PHONY: all prepare clean arithmetic alu encoding hashing generation memory ntt kem synth

SRC := src
TB := testbench
BUILD := build
LOGS := logs
IVERILOG := iverilog
VVP := vvp
ALL_SRC := $(wildcard $(SRC)/*.v) $(wildcard $(SRC)/*/*.v)

prepare:
	@mkdir -p $(BUILD)
	@mkdir -p $(LOGS)

clean:
	rm -rf $(BUILD)
	rm -rf $(LOGS)
	rm -rf runs/
	rm -f *.vcd

arithmetic: prepare
	@echo "--- Building & Running Arithmetic Tests ---"
	$(IVERILOG) -o $(BUILD)/test_add.out $(SRC)/arithmetic/mod_add.v $(TB)/arithmetic/test_add.v
	$(VVP) $(BUILD)/test_add.out > $(LOGS)/test_add.log

	$(IVERILOG) -o $(BUILD)/test_sub.out $(SRC)/arithmetic/mod_sub.v $(TB)/arithmetic/test_subtract.v
	$(VVP) $(BUILD)/test_sub.out > $(LOGS)/test_sub.log

	$(IVERILOG) -o $(BUILD)/test_mont.out $(SRC)/arithmetic/montgomery.v $(TB)/arithmetic/test_montgomery.v
	$(VVP) $(BUILD)/test_mont.out > $(LOGS)/test_mont.log

	$(IVERILOG) -o $(BUILD)/test_mult.out $(SRC)/arithmetic/mod_mult.v $(SRC)/arithmetic/montgomery.v $(TB)/arithmetic/test_mult.v
	$(VVP) $(BUILD)/test_mult.out > $(LOGS)/test_mult.log

	$(IVERILOG) -o $(BUILD)/test_to_mont.out $(SRC)/arithmetic/to_montgomery.v $(SRC)/arithmetic/montgomery.v $(TB)/arithmetic/test_to_montgomery.v
	$(VVP) $(BUILD)/test_to_mont.out > $(LOGS)/test_to_mont.log

	$(IVERILOG) -o $(BUILD)/test_from_mont.out $(SRC)/arithmetic/from_montgomery.v $(SRC)/arithmetic/montgomery.v $(TB)/arithmetic/test_from_montgomery.v
	$(VVP) $(BUILD)/test_from_mont.out > $(LOGS)/test_from_mont.log

	$(IVERILOG) -o $(BUILD)/test_mod_pipe.out $(ALL_SRC) $(TB)/arithmetic/test_mod_pipeline.v
	$(VVP) $(BUILD)/test_mod_pipe.out > $(LOGS)/test_mod_pipeline.log

alu: prepare
	@echo "--- Building & Running ALU Tests ---"
	$(IVERILOG) -o $(BUILD)/test_alu.out $(ALL_SRC) $(TB)/alu/test_alu.v
	$(VVP) $(BUILD)/test_alu.out > $(LOGS)/test_alu.log

encoding: prepare
	@echo "--- Building & Running Encoding Tests ---"
	$(IVERILOG) -o $(BUILD)/test_compress.out $(SRC)/encode/compress.v $(TB)/encoding/test_compress.v
	$(VVP) $(BUILD)/test_compress.out > $(LOGS)/test_compress.log

	$(IVERILOG) -o $(BUILD)/test_decompress.out $(SRC)/encode/decompress.v $(TB)/encoding/test_decompress.v
	$(VVP) $(BUILD)/test_decompress.out > $(LOGS)/test_decompress.log

	$(IVERILOG) -o $(BUILD)/test_pack.out $(SRC)/encode/pack.v $(TB)/encoding/test_pack.v
	$(VVP) $(BUILD)/test_pack.out > $(LOGS)/test_pack.log

	$(IVERILOG) -o $(BUILD)/test_unpack.out $(SRC)/encode/unpack.v $(TB)/encoding/test_unpack.v
	$(VVP) $(BUILD)/test_unpack.out > $(LOGS)/test_unpack.log

hashing: prepare
	@echo "--- Building & Running Hashing Tests ---"
	$(IVERILOG) -o $(BUILD)/test_keccack.out $(SRC)/hashing/keccack.v $(TB)/hashing/test_keccack.v
	$(VVP) $(BUILD)/test_keccack.out > $(LOGS)/test_keccack.log

	$(IVERILOG) -o $(BUILD)/test_sha3_256.out $(SRC)/hashing/sha3-256.v $(SRC)/hashing/keccack.v $(TB)/hashing/test_sha3-256.v
	$(VVP) $(BUILD)/test_sha3_256.out > $(LOGS)/test_sha3_256.log

	$(IVERILOG) -o $(BUILD)/test_sha3_512.out $(SRC)/hashing/sha3-512.v $(SRC)/hashing/keccack.v $(TB)/hashing/test_sha3-512.v
	$(VVP) $(BUILD)/test_sha3_512.out > $(LOGS)/test_sha3_512.log

	$(IVERILOG) -o $(BUILD)/test_shake128.out $(SRC)/hashing/shake128.v $(SRC)/hashing/keccack.v $(TB)/hashing/test_shake128.v
	$(VVP) $(BUILD)/test_shake128.out > $(LOGS)/test_shake128.log

	$(IVERILOG) -o $(BUILD)/test_shake256.out $(SRC)/hashing/shake256.v $(SRC)/hashing/keccack.v $(TB)/hashing/test_shake256.v
	$(VVP) $(BUILD)/test_shake256.out > $(LOGS)/test_shake256.log

generation: prepare
	@echo "--- Building & Running Generation Tests ---"
	$(IVERILOG) -o $(BUILD)/test_sample_ntt.out $(ALL_SRC) $(TB)/generation/test_sample_ntt.v
	$(VVP) $(BUILD)/test_sample_ntt.out > $(LOGS)/test_sample_ntt.log

	$(IVERILOG) -o $(BUILD)/test_sample_poly_CBD.out $(ALL_SRC) $(TB)/generation/test_sample_poly_CBD.v
	$(VVP) $(BUILD)/test_sample_poly_CBD.out > $(LOGS)/test_sample_poly_CBD.log

memory: prepare
	@echo "--- Building & Running Memory Tests ---"
	$(IVERILOG) -o $(BUILD)/test_address_gen.out $(SRC)/memory/address_gen.v $(TB)/memory/test_address_gen.v
	$(VVP) $(BUILD)/test_address_gen.out > $(LOGS)/test_address_gen.log

	$(IVERILOG) -o $(BUILD)/test_coeff_ram.out $(SRC)/memory/coeff_ram.v $(TB)/memory/test_coeff_ram.v
	$(VVP) $(BUILD)/test_coeff_ram.out > $(LOGS)/test_coeff_ram.log

	$(IVERILOG) -o $(BUILD)/test_twiddle_rom.out $(SRC)/memory/twiddle_rom.v $(TB)/memory/test_twiddle_rom.v
	$(VVP) $(BUILD)/test_twiddle_rom.out > $(LOGS)/test_twiddle_rom.log

	$(IVERILOG) -o $(BUILD)/test_mem_pipe.out $(ALL_SRC) $(TB)/memory/test_memory_pipeline.v
	$(VVP) $(BUILD)/test_mem_pipe.out > $(LOGS)/test_memory_pipeline.log

ntt: prepare
	@echo "--- Building & Running NTT Tests ---"
	$(IVERILOG) -o $(BUILD)/test_basemul.out $(ALL_SRC) $(TB)/ntt/test_basemul.v
	$(VVP) $(BUILD)/test_basemul.out > $(LOGS)/test_basemul.log

	$(IVERILOG) -o $(BUILD)/test_butterfly.out $(ALL_SRC) $(TB)/ntt/test_butterfly.v
	$(VVP) $(BUILD)/test_butterfly.out > $(LOGS)/test_butterfly.log

	$(IVERILOG) -o $(BUILD)/test_intt.out $(ALL_SRC) $(TB)/ntt/test_intt.v
	$(VVP) $(BUILD)/test_intt.out > $(LOGS)/test_intt.log

	$(IVERILOG) -o $(BUILD)/test_ntt256.out $(ALL_SRC) $(TB)/ntt/test_ntt.v
	$(VVP) $(BUILD)/test_ntt256.out > $(LOGS)/test_ntt256.log

	python3 $(TB)/ntt/ntt256_reference.py > $(LOGS)/ntt256_reference_py.log

kem: prepare
	@echo "--- Building & Running Full ML-KEM Top-Level ---"
	$(IVERILOG) -o $(BUILD)/test_kem.out $(ALL_SRC) $(TB)/test_kem.v
	$(VVP) $(BUILD)/test_kem.out | tee $(LOGS)/test_kem.log

synth: prepare
	@echo "--- Starting LibreLane Synthesis Flow ---"

	nix-shell --command "librelane config.json"

all: arithmetic alu encoding hashing generation memory ntt kem
	@echo "================================================="
	@echo " All tests executed! Check the logs/ directory   "
	@echo "================================================="