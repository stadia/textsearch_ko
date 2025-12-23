-- textsearch_ko regression test
--
-- Tests for Korean full-text search using mecab morphological analyzer
-- Database encoding MUST be UTF-8

-- Test 1: Create extension
CREATE EXTENSION textsearch_ko;

-- Test 2: Verify parser object
SELECT parname FROM pg_ts_parser WHERE parname = 'korean';

-- Test 3: Verify template object
SELECT tmplname FROM pg_ts_template WHERE tmplname = 'mecabko';

-- Test 4: Verify dictionary object
SELECT dictname FROM pg_ts_dict WHERE dictname = 'korean_stem';

-- Test 5: Verify configuration object
SELECT cfgname FROM pg_ts_config WHERE cfgname = 'korean';

-- Test 6: Basic morphological analysis - noun
SELECT word, type
FROM mecabko_analyze('무궁화')
WHERE word IS NOT NULL
ORDER BY word;

-- Test 7: Morphological analysis - sentence
SELECT word, type, basic
FROM mecabko_analyze('무궁화꽃이 피었습니다.')
WHERE word IS NOT NULL AND word != '.'
ORDER BY word;

-- Test 8: Filter particles and endings (to_tsvector filters them out)
SELECT to_tsvector('korean', '무궁화꽃이 피었습니다.');

-- Test 9: Mixed Korean-English text
SELECT to_tsvector('korean', 'PostgreSQL 데이터베이스');

-- Test 10: Numbers in text
SELECT to_tsvector('korean', '오늘은 2024년 12월 22일입니다.');

-- Test 11: Empty string handling
SELECT to_tsvector('korean', '');

-- Test 12: Whitespace handling
SELECT to_tsvector('korean', '   ');

-- Test 13: Multiple spaces between words
SELECT to_tsvector('korean', '무궁화     꽃이     피었습니다');

-- Test 14: Korean normalization function
SELECT korean_normalize('ＡＢＣ');

-- Test 15: Full-width number normalization
SELECT korean_normalize('１２３');

-- Test 16: Hanja to Hangul conversion
SELECT hanja2hangul('韓國');

-- Test 17: Text search query - simple match
SELECT '무궁화' @@ to_tsvector('korean', '무궁화꽃이 피었습니다.') AS match;

-- Test 18: Text search query - verb conjugation
SELECT '피' @@ to_tsvector('korean', '꽃이 피었습니다.') AS match;

-- Test 19: Text search query - no match for particles
SELECT '이' @@ to_tsvector('korean', '꽃이 피었습니다.') AS match;

-- Test 20: Part-of-speech filtering - nouns should be accepted
SELECT word, type
FROM mecabko_analyze('아름다운 꽃')
WHERE type IN ('NNG', 'NNP')
ORDER BY word;

-- Test 21: Part-of-speech filtering - particles should be present in analysis
SELECT word, type
FROM mecabko_analyze('꽃이')
WHERE type = 'JKS';

-- Test 22: Part-of-speech filtering - endings should be present in analysis
SELECT word, type
FROM mecabko_analyze('피었습니다')
WHERE type IN ('EP', 'EF');

-- Test 23: Verb analysis
SELECT word, type, basic
FROM mecabko_analyze('먹었습니다')
WHERE type IN ('VV', 'EP', 'EF')
ORDER BY type;

-- Test 24: Compound word analysis
SELECT word, detail
FROM mecabko_analyze('무궁화')
WHERE detail IS NOT NULL;

-- Test 25: Punctuation handling
SELECT word, type
FROM mecabko_analyze('문장입니다.')
WHERE type = 'SF';

-- Test 26: Long text handling
SELECT count(*) as token_count
FROM mecabko_analyze('동해물과 백두산이 마르고 닳도록 하느님이 보우하사 우리나라 만세 무궁화 삼천리 화려강산');

-- Test 27: Mixed case English text
SELECT to_tsvector('korean', 'PostgreSQL database management system');

-- Test 28: Special characters
SELECT to_tsvector('korean', '이메일: test@example.com 홈페이지: https://www.postgresql.org');

-- Test 29: Verify lexizer produces correct token types
SELECT * FROM ts_token_type('korean');

-- Test 30: Multiple analysis on same input (consistency check)
SELECT word FROM mecabko_analyze('한글') UNION ALL SELECT word FROM mecabko_analyze('한글');

-- Cleanup
DROP EXTENSION textsearch_ko CASCADE;
