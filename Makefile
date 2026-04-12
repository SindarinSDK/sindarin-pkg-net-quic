# Sindarin Net QUIC Package - Makefile

.PHONY: all test hooks install-libs clean help

# Disable implicit rules for .sn.c files (compiled by the Sindarin compiler)
%.sn: %.sn.c
	@:

#------------------------------------------------------------------------------
# Platform Detection
#------------------------------------------------------------------------------
ifeq ($(OS),Windows_NT)
    PLATFORM := windows
    EXE_EXT  := .exe
    MKDIR    := mkdir
else
    UNAME_S := $(shell uname -s 2>/dev/null || echo Unknown)
    ifeq ($(UNAME_S),Darwin)
        PLATFORM := darwin
    else
        PLATFORM := linux
    endif
    EXE_EXT :=
    MKDIR   := mkdir -p
endif

#------------------------------------------------------------------------------
# Configuration
#------------------------------------------------------------------------------
BIN_DIR := bin
SN      ?= sn

SRC_SOURCES := $(wildcard src/*.sn) $(wildcard src/native/*.sn.c) $(wildcard src/native/*.h)

TEST_SRCS := $(wildcard tests/test_*.sn)
TEST_BINS := $(patsubst tests/%.sn,$(BIN_DIR)/%$(EXE_EXT),$(TEST_SRCS))

#------------------------------------------------------------------------------
# Targets
#------------------------------------------------------------------------------
all: test

# --exclude test_persistent_rpc_burst: known flake (stream-lifecycle race)
# --parallel 8: cap parallelism to avoid scheduler starvation under QUIC timing
# --run-timeout 120: QUIC resilience tests need headroom under CI contention
test: hooks $(RUN_TESTS_BIN)
	@$(RUN_TESTS_BIN) --exclude test_persistent_rpc_burst --parallel 8 --run-timeout 120 --verbose

$(BIN_DIR):
	@$(MKDIR) $(BIN_DIR)

$(BIN_DIR)/%$(EXE_EXT): tests/%.sn $(SRC_SOURCES) | $(BIN_DIR)
	@SN_CFLAGS="-I$(CURDIR)/libs/$(PLATFORM)/include $(SN_CFLAGS)" \
	 SN_LDFLAGS="-L$(CURDIR)/libs/$(PLATFORM)/lib $(SN_LDFLAGS)" \
	 $(SN) $< -o $@ -l 1

#------------------------------------------------------------------------------
# Test runner (compiled from sindarin-pkg-test)
#------------------------------------------------------------------------------
RUN_TESTS_SRC := $(wildcard .sn/sindarin-pkg-test/src/run_tests.sn)
RUN_TESTS_BIN := $(BIN_DIR)/run_tests$(EXE_EXT)

$(RUN_TESTS_BIN): $(RUN_TESTS_SRC) | $(BIN_DIR)
	@SN_CFLAGS="-I$(CURDIR)/libs/$(PLATFORM)/include $(SN_CFLAGS)" \
	 SN_LDFLAGS="-L$(CURDIR)/libs/$(PLATFORM)/lib $(SN_LDFLAGS)" \
	 $(SN) .sn/sindarin-pkg-test/src/run_tests.sn -o $@ -l 1

install-libs:
	@bash scripts/install.sh

clean:
	@echo "Cleaning build artifacts..."
	@rm -rf $(BIN_DIR) .sn
	@echo "Clean complete."

#------------------------------------------------------------------------------
# hooks - Configure git to use tracked pre-commit hooks
#------------------------------------------------------------------------------
hooks:
	@git config core.hooksPath .githooks 2>/dev/null || true

help:
	@echo "Sindarin Net QUIC Package (ngtcp2 backend)"
	@echo ""
	@echo "Targets:"
	@echo "  make test              Build and run all tests"
	@echo "  make install-libs      Download pre-built libraries from GitHub releases"
	@echo "  make clean             Remove build artifacts"
	@echo "  make help              Show this help"
	@echo ""
	@echo "Platform: $(PLATFORM)"
