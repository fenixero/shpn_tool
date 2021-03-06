default: all
include config.mk
include rules.mk

# File containing main must be the first in the list
SRC := \
	src/main.c \
	src/script_disass.c \
	src/crc32.c \
	src/script_handlers.c \
	src/strtab.c \
	src/branch.c \
	src/script_as.c \
	src/script_parse_ctx.c \
	src/embed.c \
	src/search.c \
	src/glyph.c

SRC_TEST := \
	test/make_strtab.c \
	test/script_as.c \
	test/mk_strtab_str.c \
	test/embed_strtab.c \
	test/hard_wrap.c \
	test/break_frame.c

SRC_LEX := src/script_lex.yy.c
SRC_YACC := src/script_gram.tab.c

SRC_PARSER := $(SRC_LEX) $(SRC_YACC)

SRC += $(OBJ_LEX)
SRC += $(OBJ_YACC)

OBJ := $(SRC:src/%.c=build/%.o)
OBJ += $(SRC_PARSER:src/%.c=build/%.o)
OBJ += build/glyph_margins.o

DEP := $(OBJ:%.o=%.d)

# all but main.o
OBJ_TEST := $(wordlist 2,$(words $(OBJ)),$(OBJ))
DEP_TEST := $(OBJ_TEST:%.o=%.d)

TARGET := build/shpn_tool
TARGETS_TEST := $(SRC_TEST:test/%.c=build/test/%.sym)

include scripts/scripts.mk
include agb/patch.mk

IPS_TARGETS = $(foreach script,$(SCRIPTS),$(script:%=build/%.ips))
BPS_TARGETS = $(foreach script,$(SCRIPTS),$(script:%=build/%.bps))

$(foreach script,$(SCRIPTS),$(eval $(call MAKE_BUILD_TAG,$(script))))
$(foreach script,$(SCRIPTS),$(eval $(call MAKE_ROM,$(script))))
$(foreach script,$(SCRIPTS),$(eval $(call MAKE_IPS,$(script))))
$(foreach script,$(SCRIPTS),$(eval $(call MAKE_BPS,$(script))))

all: $(TARGET) agb $(IPS_TARGETS) $(BPS_TARGETS) | build

.PHONY: clean all test help distclean yyclean agb
.SUFFIXES:

-include $(DEP) $(DEP_TEST)

build:
	@mkdir -p build

src/%.tab.c src/%.tab.h: src/%.y
	@echo yacc $(notdir $<)
	$(VERBOSE) $(ENV) $(YACC) $(YACC_FLAGS) -o $(@:%.h=%.c) $<

src/%.yy.c src/%.yy.h: src/%.l $(SRC_YACC)
	@echo lex $(notdir $<)
	$(VERBOSE) $(ENV) $(LEX) $(LEX_FLAGS) -o $(@:%.h=%.c) $<

$(eval $(call COMPILE_C,build,src))
$(eval $(call COMPILE_C,build,agb))
$(eval $(call COMPILE_C,build/test,test))

build/script_parse_ctx.o: $(SRC_PARSER)

$(eval $(call LINK_TARGET,$(TARGET).sym,$(OBJ)))

# For each test target, link the objects from src/ (but main.o) and only the test .o we need
$(foreach test,$(TARGETS_TEST),$(eval $(call LINK_TARGET,$(test),$(OBJ_TEST) $(test:%.sym=%.o))))

agb:
	@echo make agb
	$(VERBOSE) $(MAKE) -C agb

$(TARGET): $(TARGET).sym
	@echo strip $(notdir $@)
	$(VERBOSE) $(ENV) $(STRIP) $(TARGET).sym -o $@

clean:
	@rm -rf build

yyclean:
	@rm -f $(SRC_PARSER) $(SRC_PARSER:src/%.c=src/%.h)

distclean: clean yyclean
	make -C agb clean

testdir:
	@mkdir -p build/test

test: $(TARGETS_TEST) | testdir
	-$(foreach tgt,$(TARGETS_TEST),$(tgt)$(\n))

help:
	$(info Supported targets:)
	$(info all$(\t)$(\t)$(\t)compile everything but tests)
	$(info $(TARGET)$(\t)$(\t)compile $(TARGET))
	$(info $(TARGET).sym$(\t)compile symbolised $(TARGET))
	$(info agb$(\t)$(\t)$(\t)ROM code patches)
	$(info build/LANG.rom$(\t)$(\t)translated rom for LANG)
	$(info build/LANG.ips$(\t)$(\t)IPS patch for the translation)
	$(info build/LANG.bps$(\t)$(\t)BPS patch for the translation)
	$(info test$(\t)$(\t)$(\t)run unit tests)
	$(info clean$(\t)$(\t)$(\t)remove build artefacts)
	$(info yyclean$(\t)$(\t)$(\t)remove $(SRC_PARSER))
	$(info distclean$(\t)$(\t)same as clean and yyclean)
	$(info help$(\t)$(\t)$(\t)show this message)
	$(info Supported LANG values:)
	$(info $(SCRIPTS))
	$(info Supported environment variables:)
	$(info CC)
	$(info STRIP)
	$(info FLIPS)
	$(info YACC)
	$(info LEX)
	$(info SHPN_ROM$(\t)$(\t)ROM path)
	$(info DEBUG$(\t)$(\t)$(\t)compile code with debug info, without optimisations)
	$(info ICONV$(\t)$(\t)$(\t)iconv installation prefix)
	$(info SANITIZE$(\t)$(\t)build with specified sanitizer (e.g. address))
	$(info VERBOSE$(\t)$(\t)$(\t)verbose build command logging)
	@:
