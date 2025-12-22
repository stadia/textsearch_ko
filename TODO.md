# TODO

Project task tracking and roadmap for textsearch_ko.

## Completed (v2.0)

**PostgreSQL 12-17 Modernization:**
- [x] Remove deprecated `access/heapam.h` usage
- [x] Remove redundant `heap_copytuple()` in SRF
- [x] Optimize list iteration pattern (O(n²) → O(n))
- [x] Add PostgreSQL version detection to Makefile
- [x] Require PostgreSQL 12+ minimum
- [x] Add comprehensive regression test suite (30 test cases)
- [x] Create test infrastructure (sql/ and expected/ directories)
- [x] Enhance global variable documentation
- [x] Add input validation to parser and analyzer functions
- [x] Remove unused static variables
- [x] Fix compiler warnings

**Documentation:**
- [x] Complete README.md rewrite with examples and troubleshooting
- [x] Create UPGRADING.md migration guide for PostgreSQL 9.3→12+
- [x] Add Modernization Notes to CLAUDE.md
- [x] Update CLAUDE.md architecture documentation
- [x] Update this TODO.md

## High Priority

### 1. Thread-Safe Global Variable Solution
**Rationale:** `current_node` global variable creates thread-safety issues
**Impact:** Enables parallel query execution for text search
**Effort:** High - requires significant refactoring
**Status:** Known limitation documented

**Approach:**
- [ ] Investigate PostgreSQL 18+ parser state extension mechanisms
- [ ] Research TSConfigCache usage patterns
- [ ] Prototype parallel-safe implementation
- [ ] Test with parallel query execution
- [ ] Maintain backward compatibility

**Tasks:**
- [ ] Research PostgreSQL core APIs for context passing
- [ ] Design new state management approach
- [ ] Implement thread-local or context-aware storage
- [ ] Add parallel execution tests
- [ ] Document changes for users

### 2. Stop Word (Exclusion Word) Support
**Rationale:** Users need to exclude common particles and endings
**Impact:** Improved search relevance, smaller indexes
**Effort:** Medium
**Status:** Not started

**Implementation:**
- [ ] Design configurable stop word dictionary
- [ ] Create SQL interface for stop word management
- [ ] Implement filtering in lexizer
- [ ] Add comprehensive tests
- [ ] Update documentation

**Tasks:**
- [ ] Analyze common stop words in Korean text search
- [ ] Design stop word configuration system
- [ ] Integrate with PostgreSQL dictionary framework
- [ ] Test with real-world data
- [ ] Add SQL examples to documentation

## Medium Priority

### 1. Improve hanja2hangul() Function
**Rationale:** Chinese character conversion is incomplete
**Impact:** Better handling of Chinese characters in Korean text
**Effort:** Medium
**Status:** Partially implemented

**Current Status:**
- Uses mecab-ko-dic mappings only
- Limited coverage for rare characters
- No fallback for unmapped characters

**Improvements:**
- [ ] Expand character mapping dictionary
- [ ] Add multiple romanization methods
- [ ] Implement graceful fallback for unknown characters
- [ ] Handle Japanese kanji vs Chinese hanzi distinction
- [ ] Add comprehensive tests

**Tasks:**
- [ ] Review mecab-ko-dic character mappings
- [ ] Source additional character databases
- [ ] Implement mapping selection strategy
- [ ] Add error handling for edge cases
- [ ] Update documentation with limitations

### 2. Windows Port
**Rationale:** Extend platform support
**Impact:** Windows users can use the extension
**Effort:** High - requires mecab-ko Windows build
**Status:** Not started

**Requirements:**
- Mecab-ko for Windows
- Visual Studio compiler support
- .dll instead of .so
- Library linking adjustments

**Tasks:**
- [ ] Test mecab-ko on Windows
- [ ] Set up Visual Studio build environment
- [ ] Create Windows-specific Makefile
- [ ] Test extension loading
- [ ] Document Windows installation

### 3. Performance Optimization
**Rationale:** Morphological analysis is CPU-intensive
**Impact:** Faster indexing and search for large texts
**Effort:** Medium
**Status:** Not started

**Areas:**
- [ ] Profile with large texts (>1MB)
- [ ] Memory leak testing with valgrind
- [ ] Benchmark vs other Korean text search solutions
- [ ] Optimize memory allocation patterns
- [ ] Consider caching strategies
- [ ] Parallel processing investigation

**Tasks:**
- [ ] Create performance test suite
- [ ] Profile mecab vs PostgreSQL overhead
- [ ] Identify bottlenecks
- [ ] Implement optimizations
- [ ] Benchmark improvements

### 4. Enhanced Error Messages
**Rationale:** Better diagnostics for common issues
**Impact:** Easier troubleshooting for users
**Effort:** Low-Medium
**Status:** Partially done

**Current:**
- Basic input validation added in v2.0
- Room for improvement in mecab error handling

**Improvements:**
- [ ] Better context in mecab error messages
- [ ] Suggestions for common configuration issues
- [ ] Standard error code mapping
- [ ] Enhanced error documentation

**Tasks:**
- [ ] Collect common error scenarios
- [ ] Create error message templates
- [ ] Add context-specific suggestions
- [ ] Update troubleshooting guide

## Low Priority

### 1. Configurable Part-of-Speech Filtering
**Rationale:** Different use cases need different POS filtering
**Impact:** Flexibility for specialized applications
**Effort:** Medium
**Status:** Not started

**Features:**
- [ ] Create custom text search configurations
- [ ] Allow per-configuration POS filtering
- [ ] SQL interface for filter configuration
- [ ] Multiple profiles (default, strict, loose)

**Example Use Cases:**
- Strict: Only nouns (best for search)
- Loose: Include adjectives and adverbs
- Custom: User-defined POS sets

### 2. Synonym Dictionary Support
**Rationale:** Handle Korean synonyms and aliases
**Impact:** Better search recall
**Effort:** Medium
**Status:** Not started

**Implementation:**
- [ ] Design synonym dictionary format
- [ ] Integration with PostgreSQL synonym template
- [ ] Korean synonym collections
- [ ] Testing and validation

### 3. Docker Containerization
**Rationale:** Easy development and testing environment
**Impact:** Simplified onboarding for new developers
**Effort:** Low
**Status:** Not started

**Deliverables:**
- [ ] Dockerfile with PostgreSQL, mecab-ko, textsearch_ko
- [ ] docker-compose for quick setup
- [ ] CI/CD Docker image
- [ ] Development environment documentation

### 4. Additional Utility Functions
**Rationale:** Extend functionality for specific use cases
**Impact:** More tools for users
**Effort:** Low-Medium
**Status:** Not started

**Ideas:**
- [ ] Token statistics by POS tag
- [ ] Text difficulty/readability metrics
- [ ] Morpheme segmentation utilities
- [ ] Compound word analysis tools

## Won't Fix / Known Limitations

### 1. ts_debug() Functionality
**Issue:** May show stale data due to global variable timing
**Reason:** Architectural limitation of PostgreSQL text search API
**Workaround:** Use `mecabko_analyze()` instead
**Status:** Documented in CLAUDE.md and README.md

### 2. Parallel Query Execution
**Issue:** Global `current_node` variable not thread-safe
**Reason:** PostgreSQL text search API design
**Workaround:** Parallel execution rare for text search, sequential still works
**Status:** Documented, listed for future improvement

### 3. Support for PostgreSQL 9.3-11
**Decision:** Dropped to modernize API usage
**Reason:** API compatibility vs modernization trade-off
**Workaround:** Use version 1.0 from git tag `v1.0-pg9.3`
**Status:** Final decision, documented in README.md

## Version Roadmap

### v2.0 (Current) - PostgreSQL 12-17 Modernization
- PostgreSQL 12-17 support
- Removed deprecated APIs
- Comprehensive test suite
- Complete documentation

### v2.1 (Planned) - Bug Fixes and Minor Improvements
- Bug fixes from user feedback
- Enhanced error messages
- Documentation updates

### v3.0 (Future) - Major Features
- Thread-safe global variable solution
- Stop word support
- Windows port
- Performance optimizations

### v3.1+ (Long-term)
- Synonym support
- Advanced filtering
- Platform support expansion

## Contributing Guidelines

When adding to this list:
1. Use clear, descriptive titles
2. Include rationale for each item
3. Estimate effort (Low/Medium/High)
4. Link to related issues/discussions
5. Break large features into tasks
6. Update status regularly

## Testing Standards

All new features/fixes should include:
- Unit tests or regression tests
- Documentation of test cases
- Examples of usage
- Backward compatibility verification (if applicable)

## Release Process

Before releasing a new version:
1. All high-priority items resolved or deferred
2. All tests passing
3. README.md and documentation updated
4. CHANGELOG created
5. Version number bumped
6. Git tag created (v{major}.{minor})
7. Release notes published

## Contact and Discussion

For discussions about items on this list:
- Open GitHub issue for bugs/feature requests
- Use discussion board for questions
- Reference this TODO.md in conversations
