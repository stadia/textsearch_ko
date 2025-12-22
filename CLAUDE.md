# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

textsearch_ko is a PostgreSQL extension that implements Korean full-text search using the mecab morphological analyzer. It provides a text parser and lexizer for the Korean language, along with utility functions for Korean text processing.

## Build and Installation

### Prerequisites
- PostgreSQL (15+ recommended based on README examples)
- mecab-ko (Korean morphological analyzer)
- mecab-ko-dic (Korean dictionary for mecab)
- Database encoding must be UTF-8

### Build Commands

```bash
# Standard build with PGXS
export PATH=/opt/mecab-ko/bin:/postgres/15/bin:$PATH
make USE_PGXS=1 install

# Clean build artifacts
make clean
```

The Makefile uses `pg_config` to locate PostgreSQL and `mecab-config` to locate mecab headers and libraries.

### Testing Extension

```sql
-- In psql
CREATE EXTENSION textsearch_ko;
SET default_text_search_config = korean;

-- Test morphological analyzer
SELECT * FROM mecabko_analyze('무궁화꽃이 피었습니다.');

-- Test vector conversion (filters particles and endings)
SELECT * FROM to_tsvector('무궁화꽃이 피었습니다.');

-- Test normalization functions
SELECT korean_normalize('한글');
SELECT hanja2hangul('한글');
```

## Architecture

### Core Components

**C Extension (ts_mecab_ko.c/h):**
- PostgreSQL module written in C that wraps the mecab morphological analyzer
- Implements three PostgreSQL text search interfaces:
  1. **Parser** (ts_mecabko_start/gettoken/end) - Tokenizes Korean text using mecab
  2. **Lexizer/Dictionary** (ts_mecabko_lexize) - Filters tokens by part-of-speech
  3. **Utility Functions** - Direct access to analysis results

**SQL Extension (textsearch_ko--1.0.sql):**
- Defines the Korean text search parser and lexizer in SQL
- Creates the Korean text search configuration
- Maps different token types to appropriate dictionaries:
  - ASCII words → english_stem
  - Korean words → korean_stem (uses mecabko template)
  - Numbers, URLs, emails, etc. → simple dictionary

### Key Data Structures

**parser_data struct (ts_mecab_ko.c:59-65):**
- Holds parsing state during tokenization
- `str`: Current token string being built
- `node`: Current mecab node
- `ascprs`: Internal ASCII word parser for mixed-language text
- `last_node_pos`: Position tracking for token boundaries

### Part-of-Speech Filtering

The extension accepts specific POS tags from mecab-ko-dic:
- **Nouns**: NNG (common noun), NNP (proper noun), NNB (dependent noun), NNBC, NR (number)
- **Verbs**: VV (verb), VA (adjective)
- **Modifiers**: MM (determiner), MAG (general adverb)
- **Affixes**: XSN (nominalization suffix), XR (referential suffix)
- **Special**: SH (Chinese character)

Excluded: particles (JK*), verb endings (E*), punctuation

### Encoding Requirements

- Database must use UTF-8 encoding
- mecab-ko-dic charset is checked against database encoding in `mecab_acquire()`
- Mismatch results in error to prevent data corruption

## Key Functions and Their Roles

**Parsing Pipeline (called during to_tsvector):**
1. `ts_mecabko_start()` - Initialize parser, create mecab instance
2. `ts_mecabko_gettoken()` - Get next token from text
3. `ts_mecabko_lexize()` - Filter token by POS tag, perform normalization
4. `ts_mecabko_end()` - Clean up parser

**Utility Functions (direct SQL callable):**
- `mecabko_analyze(text)` - Returns all morphological analysis details (word, POS tag, basic form, pronunciation, etc.)
- `korean_normalize(text)` - Normalizes Korean text
- `hanja2hangul(text)` - Converts Chinese characters to Hangul (incomplete - listed as TODO)

**Internal Helper Functions:**
- `accept_mecab_ko_part()` - Checks if token's POS is in accept_parts_of_speech list
- `feature()` - Extracts CSV fields from mecab's output
- `normalize()` - Normalizes and cleans token text
- `lexize()` - Formats token for output
- `ismbascii()` - Detects multi-byte ASCII sequences
- `appendString()` - Safely appends strings to StringInfo buffers

## Module Lifecycle

**Initialization (_PG_init):**
- Creates global mecab instance (_mecab)
- Called once when extension is loaded

**Finalization (_PG_fini):**
- Destroys mecab instance
- Called when module is unloaded

## Known Limitations and TODO Items

See TODO.md for the complete list. Notable items:
- Windows port not implemented
- hanja2hangul() conversion incomplete
- Stop word (exclusion word) handling not implemented
- Performance testing and memory leak checking needed
- mecab rpath configuration in .so file not documented
