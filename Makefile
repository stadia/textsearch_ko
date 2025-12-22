EXTENSION = textsearch_ko        # the extensions name
DATA = textsearch_ko--1.0.sql  # script files to install
REGRESS = textsearch_ko_test # our test script file (without extension)
REGRESS_OPTS = --inputdir=. --outputdir=.
MODULE_big = ts_mecab_ko
relocatable = true

# PostgreSQL version detection and validation
PG_CONFIG = pg_config
PGVER := $(shell $(PG_CONFIG) --version | sed 's/PostgreSQL //' | cut -d. -f1)

# Require PostgreSQL 12 or later
PGVER_CHECK := $(shell test $(PGVER) -ge 12 && echo yes || echo no)
ifeq ($(PGVER_CHECK),no)
$(error This extension requires PostgreSQL 12 or later. Current version: PostgreSQL $(PGVER))
endif

# macOS arm64 (Apple Silicon) support
ifeq ($(shell uname -s),Darwin)
    UNAME_M := $(shell uname -m)
    ifeq ($(UNAME_M),arm64)
        # Force arm64 architecture on Apple Silicon
        ARCHFLAGS ?= -arch arm64
        export ARCHFLAGS
    endif
endif

OBJS = \
	$(WIN32RES) \
	ts_mecab_ko.o

PGFILEDESC = "textsearch_ko - textsearch for korean"

MECAB_HEADER = $(shell mecab-config --inc-dir)
MECAB_LIBS = $(shell mecab-config --libs)

PG_CFLAGS += -I$(MECAB_HEADER)
PG_CPPFLAGS += -I$(MECAB_HEADER)
SHLIB_LINK += $(MECAB_LIBS)

# postgres build stuff
ifdef USE_PGXS
PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
else
subdir = contrib/textsearch_ko
top_builddir = ../..
include $(top_builddir)/src/Makefile.global
include $(top_srcdir)/contrib/contrib-global.mk
endif
