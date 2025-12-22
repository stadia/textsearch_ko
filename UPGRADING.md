# Upgrading textsearch_ko to PostgreSQL 12+

This guide helps you migrate from textsearch_ko version 1.0 on PostgreSQL 9.3-11 to the modernized version for PostgreSQL 12-17.

## Before You Begin: Prerequisites Check

### Check Your Current PostgreSQL Version

```bash
psql -c "SELECT version();"
```

**Supported versions for upgrade:**
- PostgreSQL 9.3 → 12+ (requires full PostgreSQL upgrade first)
- PostgreSQL 10.x → 12+ (requires full PostgreSQL upgrade first)
- PostgreSQL 11.x → 12+ (requires full PostgreSQL upgrade first)
- PostgreSQL 12+ → 17 (in-place upgrade possible)

### Check Database Encoding

```bash
psql -c "SHOW server_encoding;"
```

**MUST be UTF-8!** If not, the extension will not work.

```bash
# Create new UTF-8 database
createdb -E UTF-8 -T template0 new_database_name
```

### Check mecab-ko Installation

```bash
mecab --version
mecab-ko-config --version  # if available
```

**Recommended versions:**
- mecab-ko: 0.996-ko-0.9.2 or later
- mecab-ko-dic: 2.1.1-20180720 or later

## Upgrade Process by PostgreSQL Version

### Scenario 1: PostgreSQL 9.3/10/11 → 12+

If you're currently on PostgreSQL 9.3-11, you **MUST upgrade PostgreSQL first**. Follow PostgreSQL's official upgrade documentation:

- [PostgreSQL Upgrade Guide](https://www.postgresql.org/docs/current/upgrading.html)
- [pg_upgrade Documentation](https://www.postgresql.org/docs/current/pgupgrade.html)

After upgrading PostgreSQL, continue with **Scenario 2** below.

### Scenario 2: PostgreSQL 12+ → Newer Version (12→13→14→...→17)

For in-place PostgreSQL upgrades within the 12+ series:

#### Step 1: Backup Your Database

```bash
# Create a backup before any changes
pg_dump -Fc your_database > backup_before_upgrade.dump

# Store it safely
cp backup_before_upgrade.dump ~/backups/
```

#### Step 2: Note Current Extension Status

```bash
# Check if extension is installed
psql -c "
SELECT extname, extversion, nspname
FROM pg_extension
LEFT JOIN pg_namespace ON pg_extension.extnamespace = pg_namespace.oid
WHERE extname = 'textsearch_ko';
"

# Note any custom text search configurations
psql -c "
SELECT cfgname, cfgparser, cfgdict
FROM pg_ts_config
WHERE cfgparser IN (
  SELECT oid FROM pg_ts_parser WHERE parname = 'korean'
);
"
```

#### Step 3: Drop Old Extension (IMPORTANT)

The old version may not be compatible. You must drop it first:

```bash
# Connect to your database
psql your_database

# Inside psql:
DROP EXTENSION IF EXISTS textsearch_ko CASCADE;
```

**WARNING**: This will drop:
- Custom text search configurations using the Korean parser
- All GIN/GIST indexes on `tsvector` columns
- Triggers using `tsvector_update_trigger`

**To preserve indexes and triggers**, save them first:

```bash
# Save index definitions
psql -d your_database -c "
SELECT schemaname, tablename, indexdef
FROM pg_indexes
WHERE indexdef LIKE '%korean%' OR indexdef LIKE '%tsvector%';" > indexes.sql

# Save trigger definitions
psql -d your_database -c "
SELECT schemaname, tablename, tgname, pg_get_triggerdef(oid)
FROM pg_trigger
WHERE tgname LIKE '%tsvector%';" > triggers.sql

# Save tsvector columns definition
psql -d your_database -c "
SELECT table_schema, table_name, column_name, data_type
FROM information_schema.columns
WHERE data_type = 'tsvector';" > tsvector_columns.sql
```

#### Step 4: Upgrade PostgreSQL

Follow PostgreSQL official instructions for your platform:

**For Linux (Debian/Ubuntu):**

```bash
# Update package lists
sudo apt update

# Upgrade PostgreSQL (example: 15 to 16)
sudo apt upgrade postgresql-16

# Check if new version is running
pg_config --version
```

**For macOS (using Homebrew):**

```bash
# Update formulae
brew update

# Upgrade PostgreSQL
brew upgrade postgresql

# If using Postgres.app, use their installer
```

**For other platforms:** See [PostgreSQL Downloads](https://www.postgresql.org/download/)

#### Step 5: Install New Extension Version

```bash
# Remove old version from system
cd /path/to/old/textsearch_ko
sudo make USE_PGXS=1 uninstall

# Build and install new version
cd /path/to/new/textsearch_ko
make USE_PGXS=1 clean
make USE_PGXS=1
sudo make USE_PGXS=1 install

# Verify installation
make USE_PGXS=1 installcheck  # Requires mecab-ko and mecab-ko-dic
```

#### Step 6: Recreate Extension in Database

```bash
psql your_database

-- Inside psql:
CREATE EXTENSION textsearch_ko;

-- Verify it loaded correctly
SELECT * FROM pg_extension WHERE extname = 'textsearch_ko';
```

#### Step 7: Recreate Indexes and Triggers

If you saved them in Step 3:

```bash
# Recreate tsvector columns and triggers
psql -d your_database -f triggers.sql
psql -d your_database -f indexes.sql

# Or manually recreate
CREATE INDEX documents_tsv_idx ON documents USING GIN(content_tsv);

CREATE TRIGGER tsvectorupdate BEFORE INSERT OR UPDATE ON documents
FOR EACH ROW EXECUTE FUNCTION
tsvector_update_trigger(content_tsv, 'public.korean', content);
```

#### Step 8: Verify Functionality

```bash
-- Test basic analysis
SELECT * FROM mecabko_analyze('테스트 문장');

-- Test search vector
SELECT to_tsvector('korean', '테스트 문장');

-- Test on your data
SELECT * FROM documents
WHERE to_tsvector('korean', content) @@ to_tsquery('korean', '검색')
LIMIT 5;

-- Check index health
SELECT schemaname, tablename, indexname, idx_scan
FROM pg_stat_user_indexes
WHERE indexname LIKE '%tsv%';
```

## Testing for Compatibility

### Test on Staging First

**Strongly recommended** - test on non-production database first:

```bash
# Create test database
createdb -T your_database test_upgrade

# Perform upgrade steps on test_upgrade
# Test thoroughly
# Confirm results match expectations

# If successful, proceed with production
# If issues, restore original database
```

### Comparison Test

Compare search results before and after:

```sql
-- Save old results (before extension drop)
CREATE TABLE old_results AS
SELECT id, content, to_tsvector('korean', content) as tsv
FROM documents;

-- After upgrade, compare
CREATE TABLE new_results AS
SELECT id, content, to_tsvector('korean', content) as tsv
FROM documents;

-- Find differences (should be none for same mecab-ko-dic version)
SELECT o.id, o.content
FROM old_results o
FULL OUTER JOIN new_results n ON o.id = n.id
WHERE o.tsv IS DISTINCT FROM n.tsv
LIMIT 10;
```

Note: Minor differences are possible if mecab-ko-dic version changed.

## What Changed Between Versions

### API Changes

**Removed:**
- Dependency on deprecated `access/heapam.h` header (PostgreSQL 12+)

**Improved:**
- Memory management in Set-Returning Functions (SRF)
- List iteration performance (O(n²) → O(n))

### Behavior Changes

**None**: SQL interface unchanged
- Search results identical to v1.0 (assuming same mecab-ko-dic)
- Text normalization unchanged
- Function signatures unchanged

### New Features

- Comprehensive regression tests
- Better input validation
- Improved error messages
- Build-time PostgreSQL version checking

### Removed Features

**None**: All v1.0 features preserved

## Troubleshooting

### Extension Fails to Load

**Error**: `ERROR: could not load library...`

**Solution**:

```bash
# Check if extension is installed
pg_config --pkglibdir
ls -la /usr/local/pgsql/lib/ts_mecab_ko.so

# Check shared library dependencies
ldd /usr/local/pgsql/lib/ts_mecab_ko.so  # Linux
otool -L /usr/local/pgsql/lib/ts_mecab_ko.so  # macOS

# Fix library path issues
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
sudo ldconfig  # Linux only
```

### "PostgreSQL 12 or later required"

**Error**: Build fails with "This extension requires PostgreSQL 12 or later"

**Solution**:
- Install PostgreSQL 12+ first
- Check `pg_config --version`
- Update your PostgreSQL installation

### Different Search Results After Upgrade

**Possible cause**: Different mecab-ko-dic version

**Solution**:

```bash
# Check dictionary version
mecab --version  # Shows mecab version
# Dictionary version is in mecab-ko-dic package

# Install same version if results must match exactly
# Otherwise accept minor differences (usually minimal)
```

### Performance Regression

**Unlikely** but if observed:

```sql
-- Rebuild indexes
REINDEX INDEX documents_tsv_idx;

-- Update statistics
ANALYZE documents;

-- Check query plan
EXPLAIN ANALYZE
SELECT * FROM documents
WHERE to_tsvector('korean', content) @@ to_tsquery('korean', '검색');
```

### ts_debug() Still Not Working

**This is expected**. ts_debug() has limitations due to PostgreSQL API constraints. Use instead:

```sql
-- Use mecabko_analyze() for debugging
SELECT * FROM mecabko_analyze('문장');

-- Check what to_tsvector() produces
SELECT to_tsvector('korean', '문장');
```

## Rollback Procedure

If you encounter issues, you can rollback:

### Step 1: Drop New Extension

```bash
psql your_database

-- Inside psql:
DROP EXTENSION IF EXISTS textsearch_ko CASCADE;
```

### Step 2: Uninstall New Version

```bash
cd /path/to/new/textsearch_ko
sudo make USE_PGXS=1 uninstall
```

### Step 3: Reinstall Old Version

```bash
# Restore PostgreSQL to previous version
# (Platform-specific, see PostgreSQL documentation)

cd /path/to/old/textsearch_ko
git checkout v1.0-pg9.3  # Or your previous version tag
make USE_PGXS=1 clean
make USE_PGXS=1
sudo make USE_PGXS=1 install
```

### Step 4: Restore Database From Backup

```bash
# Restore backup
pg_restore -d your_database backup_before_upgrade.dump
```

## Version Compatibility Matrix

| textsearch_ko | PostgreSQL | mecab-ko | mecab-ko-dic | Status |
|-------------|------------|----------|--------------|--------|
| v1.0        | 9.3-11     | 0.996+   | 2.1.1+       | Legacy |
| v2.0        | 12-17      | 0.996+   | 2.1.1+       | Current|

## Getting Help

If you encounter issues not covered here:

1. **Check this guide** for your specific scenario
2. **Review logs**:
   ```bash
   # PostgreSQL log
   tail -f /var/log/postgresql/postgresql.log

   # Build log
   make clean && make USE_PGXS=1 2>&1 | tee build.log
   ```

3. **Verify environment**:
   ```bash
   pg_config --version
   mecab --version
   psql -c "SHOW server_encoding"
   psql -c "SELECT version()"
   ```

4. **Test installation** (if installed):
   ```bash
   psql template1
   CREATE EXTENSION textsearch_ko;
   SELECT * FROM mecabko_analyze('테스트');
   ```

5. **Open GitHub issue** with:
   - PostgreSQL version
   - mecab-ko version
   - Error messages (full stack trace)
   - Environment details (OS, architecture)
   - Steps to reproduce

## Post-Upgrade Checklist

- [ ] PostgreSQL version 12+ verified with `pg_config --version`
- [ ] Database encoding is UTF-8 with `SHOW server_encoding`
- [ ] Extension installed: `CREATE EXTENSION textsearch_ko`
- [ ] Basic function works: `SELECT * FROM mecabko_analyze('테스트')`
- [ ] Search vector created: `SELECT to_tsvector('korean', '테스트')`
- [ ] Indexes recreated and accessible
- [ ] Triggers recreated and functioning
- [ ] Application tests pass
- [ ] Production deployment plan ready
- [ ] Rollback procedure tested
- [ ] Monitoring alerts configured

## Success Criteria

After upgrade, you should see:

```sql
-- Version check
SELECT version();
-- PostgreSQL 12.x, 13.x, 14.x, 15.x, 16.x, or 17.x

-- Extension check
SELECT extversion FROM pg_extension WHERE extname = 'textsearch_ko';
-- Should return "1.0" (same SQL version as v1.0)

-- Function check
SELECT * FROM mecabko_analyze('무궁화꽃이 피었습니다.');
-- Should analyze correctly

-- Search check
SELECT to_tsvector('korean', '무궁화꽃이 피었습니다.');
-- Should return: '꽃':2 '무궁화':1 '피':3

-- Performance check
EXPLAIN ANALYZE
SELECT * FROM documents
WHERE to_tsvector('korean', content) @@ to_tsquery('korean', '검색');
-- Should use your indexes efficiently
```

## Additional Resources

- [PostgreSQL Upgrade Documentation](https://www.postgresql.org/docs/current/upgrading.html)
- [PostgreSQL Full Text Search](https://www.postgresql.org/docs/current/textsearch.html)
- [CLAUDE.md](CLAUDE.md) - Developer architecture guide
- [README.md](README.md) - Usage guide
