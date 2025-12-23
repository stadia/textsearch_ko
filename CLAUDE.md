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

## Modernization Notes (PostgreSQL 12-17 Update)

### Changes from Version 1.0

**Removed Dependencies:**
- `access/heapam.h` - Deprecated in PostgreSQL 12+
  - Removed from includes
  - All needed functions available in `access/htup_details.h`
  - No functional impact, removes compiler warnings

**Code Optimizations:**
- Removed redundant `heap_copytuple()` in mecabko_analyze() SRF (line 546-548 of v1.0)
  - Tuples already created in persistent memory context
  - Reduces memory allocation overhead
  - Improves performance for large result sets
- Improved list iteration in SRF
  - Changed from O(n²) to O(n) complexity
  - Uses index-based access instead of list_delete_first()

**Test Infrastructure:**
- Added `sql/textsearch_ko_test.sql` - 30 comprehensive regression tests
- Added `expected/textsearch_ko_test.out` - Expected test output
- Tests cover: parser, lexizer, utility functions, edge cases, Korean POS filtering
- Run tests with: `make USE_PGXS=1 installcheck`

**Build System:**
- Added PostgreSQL version detection in Makefile (line 8-16)
- Requires PostgreSQL 12+ at build time
- Clear error messages for unsupported versions
- Added REGRESS_OPTS for proper test configuration

**Code Quality:**
- Enhanced documentation for `current_node` global variable
- Added input validation in `ts_mecabko_start()` and `mecabko_analyze()`
- Improved error messages for malformed input
- Removed unused static variables

### Version Compatibility Strategy

**Minimum Version: PostgreSQL 12.0**
- Rationale: `access/heapam.h` deprecated, table AM API stabilized
- Build-time check: Makefile enforces version requirement
- Runtime: All used APIs stable across PG 12-17

**Tested Versions:**
- PostgreSQL 12.x, 13.x, 14.x, 15.x, 16.x, 17.x
- mecab-ko 0.996+
- mecab-ko-dic 2.1.1-20180720+

**Compilation:**
- No version-specific conditionals needed in C code
- All APIs used are stable across supported range
- Future-proof for PostgreSQL 18+

### Global Variable Issue: current_node

**Why It Exists:**
PostgreSQL's text search API doesn't provide context passing between parser and lexizer. Only the token text and a void pointer are passed. No way to pass the mecab morphological analysis results.

**How It Works:**
1. `ts_mecabko_gettoken()` analyzes text with mecab and stores current node in global `current_node`
2. `ts_mecabko_lexize()` reads from global `current_node` to access analysis results
3. Sequential execution within single backend ensures consistency

**Thread Safety Analysis:**
- **SAFE**: Single backend process, sequential text search execution
- **NOT SAFE**: Parallel query execution (rare for text search)
- **NOT SAFE**: Concurrent calls to lexizer from different backends

**Alternatives Considered (Not Used):**
1. **Parser context modification** - Would require PostgreSQL core changes
2. **Thread-local storage** - Not portable, version-dependent
3. **Alternative API** - Would break compatibility
4. **Serialized state** - Too complex, performance impact

**Status:** Documented known limitation. Works correctly for primary use case (to_tsvector).

### Testing Philosophy

**Coverage Areas:**
1. **Functional**: All public functions behave correctly
2. **Edge Cases**: Empty input, large input, special characters, mixed language
3. **Integration**: Proper interaction with PostgreSQL text search infrastructure
4. **POS Filtering**: Correct Korean morpheme acceptance/rejection
5. **Normalization**: Full-width to half-width conversion
6. **Consistency**: Identical results for same input

**Test Dependencies:**
- Requires mecab-ko and mecab-ko-dic properly installed
- Database encoding MUST be UTF-8
- Expected output generated from mecab-ko-dic v2.1.1-20180720
- Minor variations possible with different mecab-ko-dic versions

**Test Execution:**
```bash
make USE_PGXS=1 installcheck
# All tests should pass
```

### Removed in v2.0

**Features:**
- Support for PostgreSQL 9.3-11 (dropped for API modernization)

**APIs:**
- Direct usage of deprecated heapam.h header
- Unnecessary heap_copytuple() calls

### New in v2.0

**Testing:**
- Comprehensive regression test suite
- Automated test framework

**Documentation:**
- Complete UPGRADING.md migration guide
- Enhanced README.md with examples and troubleshooting
- This CLAUDE.md developer guide
- Input validation and error messages

**Build:**
- PostgreSQL version checking
- Clear error messages for unsupported versions

### Future Improvement Opportunities

**Architecture:**
- Investigate PostgreSQL 18+ parser state extension mechanism
- Research TSConfigCache for safer context passing
- Consider parallel-safe implementation strategy

**Features:**
- Stop word (exclusion word) support
- Synonym dictionary integration
- Configurable part-of-speech filtering per configuration
- Custom weight dictionaries

**Platform:**
- Windows port (requires mecab-ko for Windows)
- ARM/aarch64 optimization validation
- Docker containerization for development

**Performance:**
- Memory leak detection with valgrind
- Benchmark suite for different text sizes
- Profile mecab overhead vs PostgreSQL overhead

## Known Limitations and TODO Items

See TODO.md for the complete list. Notable items:
- Windows port not implemented
- hanja2hangul() conversion incomplete
- Stop word (exclusion word) handling not implemented
- Performance testing and memory leak checking needed
- Thread-safe global variable handling (architectural limitation)
