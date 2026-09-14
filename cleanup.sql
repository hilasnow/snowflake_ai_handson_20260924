-- =============================================================
-- cleanup.sql - ハンズオン環境クリーンアップ
--
-- Part 1・Part 2 で作成したオブジェクトをまとめて削除します。
-- ハンズオン終了後に実行してください。
-- =============================================================
USE ROLE ACCOUNTADMIN;

-- -----------------------------------------------
-- Part 1 で作成したオブジェクト
-- -----------------------------------------------
DROP TABLE IF EXISTS AI_HANDSON_DB.ANALYTICS.sns_mentions_classified;
DROP TABLE IF EXISTS AI_HANDSON_DB.ANALYTICS.image_features;
DROP TABLE IF EXISTS AI_HANDSON_DB.ANALYTICS.work_ai_similarity_match;
DROP WAREHOUSE IF EXISTS AI_HANDSON_ADAPTIVE_WH;

-- -----------------------------------------------
-- Part 2 で作成したオブジェクト
-- -----------------------------------------------
DROP CORTEX SEARCH SERVICE IF EXISTS AI_HANDSON_DB.ANALYTICS.product_spec_search;
DROP SEMANTIC VIEW IF EXISTS AI_HANDSON_DB.ANALYTICS.SV_STEP1;
DROP SEMANTIC VIEW IF EXISTS AI_HANDSON_DB.ANALYTICS.SV_STEP2;

-- -----------------------------------------------
-- setup.sql で作成した共通オブジェクト
-- -----------------------------------------------
DROP DATABASE IF EXISTS AI_HANDSON_DB;
DROP WAREHOUSE IF EXISTS AI_HANDSON_WH;
