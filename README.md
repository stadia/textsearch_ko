# textsearch_ko

PostgreSQL extension for Korean full-text search using mecab morphological analyzer.

PostgreSQL 데이터베이스 서버에서 사용할 한글 형태소 분석기 기반 전문 검색 모듈입니다.

## Version Compatibility

- **PostgreSQL**: 12, 13, 14, 15, 16, 17
- **Minimum required**: PostgreSQL 12.0
- **Database encoding**: UTF-8 (required)
- **mecab-ko**: 0.996 or later
- **mecab-ko-dic**: 2.1.1-20180720 or later

For PostgreSQL 9.3-11 support, use version 1.0 (git tag: v1.0-pg9.3).

## Prerequisites

### 1. Install mecab-ko

See: https://bitbucket.org/eunjeon/mecab-ko

```bash
# Clone and build
git clone https://bitbucket.org/eunjeon/mecab-ko.git
cd mecab-ko
./configure
make
sudo make install

# On aarch64/ARM64, add --build flag
./configure --build=aarch64-unknown-linux-gnu
make
sudo make install
```

### 2. Install mecab-ko-dic

See: https://bitbucket.org/eunjeon/mecab-ko-dic

```bash
git clone https://bitbucket.org/eunjeon/mecab-ko-dic.git
cd mecab-ko-dic
./configure
make
sudo make install
```

## Installation

### Important: Database encoding MUST be UTF-8!

```bash
# Set up paths for mecab-ko and PostgreSQL
export PATH=/usr/local/bin:$PATH  # or /opt/mecab-ko/bin
export PATH=/usr/local/pgsql/bin:$PATH  # or your PostgreSQL bin directory

# Build and install the extension
cd /path/to/textsearch_ko
make USE_PGXS=1 clean
make USE_PGXS=1
sudo make USE_PGXS=1 install

# Run regression tests (optional but recommended)
make USE_PGXS=1 installcheck
```

### Troubleshooting Build Issues

**Library Path Issues**:

If you get "libmecab.so not found" errors at runtime:

```bash
# Linux
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
sudo ldconfig

# macOS
export DYLD_LIBRARY_PATH=/usr/local/lib:$DYLD_LIBRARY_PATH

# Add to ~/.bashrc or ~/.bash_profile for permanent fix
echo 'export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH' >> ~/.bashrc
source ~/.bashrc
```

**PostgreSQL Version Check**:

The build system requires PostgreSQL 12+. Check your version:

```bash
pg_config --version
# PostgreSQL 15.x, 16.x, or 17.x
```

**mecab-config Not Found**:

Make sure mecab-ko installation is in your PATH:

```bash
mecab-config --version
mecab-config --libs
mecab-config --cflags
```

## Usage

### Enable Extension

```sql
CREATE EXTENSION textsearch_ko;

-- Set Korean as default search configuration
SET default_text_search_config = korean;
```

### Test Morphological Analysis

```sql
-- Basic analysis of a Korean sentence
SELECT * FROM mecabko_analyze('무궁화꽃이 피었습니다.');

 word  | type | part1st | partlast | pronounce | conjtype | conjugation | basic | detail
-------+------+---------+----------+-----------+----------+-------------+-------+---------
 무궁화 | NNG  |         | F        | 무궁화    | Compound |             |       | 무궁+화
 꽃     | NNG  |         | T        | 꽃        |          |             |       |
 이     | JKS  |         | F        | 이        |          |             |       |
 피     | VV   |         | F        | 피        |          |             |       |
 었     | EP   |         | T        | 었        |          |             |       |
 습니다 | EF   |         | F        | 습니다    |          |             |       |
 .      | SF   |         |          | .         |          |             |       |
```

### Create Search Vector

```sql
-- Converts to search vector (filters particles and endings)
SELECT to_tsvector('korean', '무궁화꽃이 피었습니다.');

      to_tsvector
--------------------------
 '꽃':2 '무궁화':1 '피':3
```

Notice how particles (이) and endings (었, 습니다) are filtered out, leaving only meaningful words.

### Full-Text Search

```sql
-- Text search with different conjugations
SELECT to_tsvector('korean', '그래서, 무궁화꽃이 피겠는걸요?');

      to_tsvector
--------------------------
 '꽃':2 '무궁화':1 '피':3

-- Query matching
SELECT '무궁화' @@ to_tsvector('korean', '무궁화꽃이 피었습니다.') AS matches;
 matches
---------
 t
```

### Create Searchable Table

```sql
CREATE TABLE documents (
    id serial PRIMARY KEY,
    title text,
    content text,
    content_tsv tsvector
);

-- Create GIN index for fast searching
CREATE INDEX documents_tsv_idx ON documents USING GIN(content_tsv);

-- Trigger to update tsvector automatically
CREATE TRIGGER tsvectorupdate BEFORE INSERT OR UPDATE ON documents
FOR EACH ROW EXECUTE FUNCTION
tsvector_update_trigger(content_tsv, 'public.korean', content);

-- Insert sample document
INSERT INTO documents (title, content)
VALUES ('한글 테스트', '무궁화꽃이 피었습니다.');

-- Search
SELECT title, content FROM documents
WHERE content_tsv @@ to_tsquery('korean', '무궁화');
```

## SQL Functions and Objects

### Text Search Parser
- **korean** - Text search parser for Korean language

### Dictionary
- **korean_stem** - Dictionary using mecab morphological analyzer

### Text Search Configuration
- **korean** - Pre-configured text search configuration for Korean
  - Korean words → korean_stem (mecab analyzer)
  - English words → english_stem (built-in)
  - Numbers, URLs, emails → simple dictionary

### Utility Functions

#### mecabko_analyze(text) → setof record
Returns detailed morphological analysis results:

```sql
SELECT * FROM mecabko_analyze('테스트 문장');
```

Output columns:
- `word` - Surface form (분석한 단어)
- `type` - Part-of-speech tag
- `part1st` - First POS classifier
- `partlast` - Last POS classifier
- `pronounce` - Pronunciation
- `conjtype` - Conjugation type (for verbs)
- `conjugation` - Conjugation details
- `basic` - Basic/dictionary form
- `detail` - Detailed analysis (compound words, etc.)
- `lucene` - Lucene-style output

#### korean_normalize(text) → text
Normalizes Korean text:
- Converts full-width ASCII characters to half-width
- Converts special number formats
- Handles spacing

```sql
SELECT korean_normalize('ＡＢＣ １２３');
-- Output: ABC 123
```

#### hanja2hangul(text) → text
Converts Chinese characters (Hanja) to Korean Hangul pronunciation:

```sql
SELECT hanja2hangul('韓國語');
-- Output: 한국어
```

Note: Uses mecab-ko-dic mappings. Results depend on dictionary version.

## Part-of-Speech Tags

### Accepted for Text Indexing

These POS tags are accepted and indexed for search:

- **Nouns**: NNG (common noun), NNP (proper noun), NNB (dependent noun), NNBC, NR (number)
- **Verbs**: VV (verb), VA (adjective)
- **Modifiers**: MM (determiner), MAG (general adverb)
- **Affixes**: XSN (nominalization suffix), XR (referential suffix)
- **Special**: SH (Chinese character)

### Filtered Out for Text Indexing

These are analyzed but not indexed:

- **Particles**: JKS (subject case), JKC (object case), etc.
- **Verb Endings**: EP (pre-final ending), EF (final ending)
- **Punctuation**: SF (sentence final), SP (opening parenthesis), etc.
- **Spaces**: Space tokens

## Known Limitations

1. **ts_debug() function**: May not work correctly due to internal architecture limitations. Use `mecabko_analyze()` instead for debugging.

2. **Parallel queries**: The lexizer uses internal state that is not thread-safe. Works correctly for normal queries (which are sequential) but may have issues with parallel query execution.

3. **Dictionary version sensitivity**: Results may vary slightly depending on mecab-ko-dic version. Tests are based on version 2.1.1-20180720.

4. **hanja2hangul()**: Chinese character conversion is incomplete for some rare characters. Dictionaries and Hanja mappings are limited to mecab-ko-dic content.

## Performance Recommendations

### Indexing Large Text Columns

Morphological analysis is CPU-intensive. For large text columns:

```sql
-- Create materialized view with pre-computed tsvectors
CREATE MATERIALIZED VIEW documents_indexed AS
SELECT id, title, to_tsvector('korean', content) as content_tsv
FROM documents;

CREATE INDEX documents_mv_tsv_idx ON documents_indexed USING GIN(content_tsv);
```

### Query Optimization

```sql
-- Use tsquery for faster searches
SELECT * FROM documents
WHERE to_tsvector('korean', content) @@ to_tsquery('korean', '검색 & 쿼리')
LIMIT 10;

-- Index the tsvector column for fastest searches
CREATE INDEX CONCURRENTLY documents_tsv_idx
ON documents USING GIN(content_tsv);
```

### Statistics

```sql
-- Update table statistics for query planner
ANALYZE documents;

-- Rebuild index if it grows large
REINDEX INDEX documents_tsv_idx;
```

## Upgrading from PostgreSQL 9.3-11

See [UPGRADING.md](UPGRADING.md) for a complete migration guide from version 1.0.

## Development

### Running Tests

```bash
make USE_PGXS=1 installcheck
```

Test files:
- `sql/textsearch_ko_test.sql` - Test cases
- `expected/textsearch_ko_test.out` - Expected output

### Contributing

Contributions welcome! Please:
1. Add tests for new features
2. Ensure `make installcheck` passes
3. Update documentation
4. Follow existing code style

## License

BSD License - See LICENSE file

## Credits

- Original textsearch_ja by Hironobu Suzuki
- Modified for Korean by Ioseph Kim (2014)
- Modernized for PostgreSQL 12-17
- Uses mecab-ko and mecab-ko-dic by Yongwoon Lee and Yungho Yu

## Related Links

- [mecab-ko](https://bitbucket.org/eunjeon/mecab-ko) - Korean morphological analyzer
- [mecab-ko-dic](https://bitbucket.org/eunjeon/mecab-ko-dic) - Korean dictionary
- [PostgreSQL](https://www.postgresql.org/) - Database
- [PostgreSQL Full Text Search](https://www.postgresql.org/docs/current/textsearch.html) - Official documentation
