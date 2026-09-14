-- =============================================================
-- setup.sql - ハンズオン共通 事前セットアップ(Part 1・Part 2)
--
-- シナリオ: インフルエンサー投稿画像 × 売上効果分析
--   旅行グッズブランドのマーケ担当が、インフルエンサー施策の効果を分析する。
--   SNS投稿画像を AI で構造化し、売上データと掛け合わせて
--   「どんな写真が売上に貢献するか」を CoWork で分析する。
--
-- この setup.sql で Part 1・Part 2 すべての環境を作成します。
-- データ(CSV・JSON・画像・PDF)は GitHub の公開リポジトリから自動取得します。
-- ローカルへのダウンロードやファイルの手動アップロードは不要です。
-- =============================================================
--
-- ⚠️ このファイルは直接貼り付けなくてOKです。
-- 参加者は代わりに load.sql(数行)だけを Snowsight のワークシートに
-- 貼り付けて実行してください。load.sql が Git 連携を設定し、
-- この setup.sql を自動取得・自動実行します。
--
-- 【Notebook の開き方】
-- Part 1・Part 2 の Notebook はこの setup.sql では作成しません。
-- Snowsight 左メニュー → Projects → Notebooks → 右上「+ Notebook」
--   →「Import from Repository」を選択し、以下を指定してインポートしてください。
--     Repository: AI_HANDSON_GIT_REPO(AI_HANDSON_GIT_DB.GIT スキーマ配下)
--     Branch    : main
--     Path      : part1_snowflake_basics_ai.ipynb / part2_cowork.ipynb
-- =============================================================
-- 参照リポジトリ: https://github.com/hilasnow/snowflake_ai_handson_20260924
-- =============================================================

-- -----------------------------------------------
-- Step 1. ロール・クロスリージョン推論・ウェアハウス
-- -----------------------------------------------
USE ROLE ACCOUNTADMIN;

-- AI 関数で利用するモデルがリージョンに無い場合に他リージョンへルーティングする
ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';

CREATE WAREHOUSE IF NOT EXISTS AI_HANDSON_WH
    WAREHOUSE_SIZE      = 'xsmall'
    WAREHOUSE_TYPE      = 'standard'
    AUTO_SUSPEND        = 60
    AUTO_RESUME         = TRUE
    INITIALLY_SUSPENDED = TRUE;

USE WAREHOUSE AI_HANDSON_WH;

-- -----------------------------------------------
-- Step 2. データベース・スキーマ・ステージ
--
-- ステージは用途別に2つ作成します。
--   DATA_STAGE  : CSV・PDF 用
--   POST_IMAGES : 投稿画像用
-- 画像・PDF を AI 関数(TO_FILE)から読むため、
-- DIRECTORY 有効化 + SNOWFLAKE_SSE 暗号化が必要です。
-- -----------------------------------------------
CREATE OR REPLACE DATABASE AI_HANDSON_DB;
CREATE OR REPLACE SCHEMA AI_HANDSON_DB.ANALYTICS;
USE SCHEMA AI_HANDSON_DB.ANALYTICS;

CREATE OR REPLACE STAGE DATA_STAGE
    ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE')
    DIRECTORY  = (ENABLE = TRUE)
    COMMENT    = 'CSV・PDF 用ステージ';

CREATE OR REPLACE STAGE POST_IMAGES
    ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE')
    DIRECTORY  = (ENABLE = TRUE)
    COMMENT    = 'SNS 投稿画像用ステージ';

-- -----------------------------------------------
-- Step 3. Git リポジトリからステージへファイルをコピー
--
-- Git連携(API INTEGRATION・GIT REPOSITORY)は load.sql で
-- AI_HANDSON_GIT_DB.GIT スキーマに作成済みです。ここでは
-- そのリポジトリからCSV・PDF・JSON・画像を取得するだけです。
-- -----------------------------------------------
-- 最新コミットを取得(load.sql 実行後に更新があった場合の保険)
ALTER GIT REPOSITORY AI_HANDSON_GIT_DB.GIT.ai_handson_git_repo FETCH;

-- CSV(6ファイル)
COPY FILES INTO @DATA_STAGE
FROM @AI_HANDSON_GIT_DB.GIT.ai_handson_git_repo/branches/main/
PATTERN = 'data/csv/.*[.]csv';

-- 商品スペックシート PDF(5商品分、作成済み)
COPY FILES INTO @DATA_STAGE
FROM @AI_HANDSON_GIT_DB.GIT.ai_handson_git_repo/branches/main/
PATTERN = 'data/pdf/.*[.]pdf';

-- SNS 投稿サンプルデータ(Part 1 の AI 関数デモ用、265件)
COPY FILES INTO @DATA_STAGE
FROM @AI_HANDSON_GIT_DB.GIT.ai_handson_git_repo/branches/main/
PATTERN = 'data/json/.*[.]json';

-- 投稿画像(53枚)
COPY FILES INTO @POST_IMAGES
FROM @AI_HANDSON_GIT_DB.GIT.ai_handson_git_repo/branches/main/
PATTERN = 'data/images/.*[.]jpg';

-- DIRECTORY テーブルを更新(ファイル一覧を反映)
ALTER STAGE DATA_STAGE REFRESH;
ALTER STAGE POST_IMAGES REFRESH;

-- -----------------------------------------------
-- Step 4. ファイルフォーマット
-- -----------------------------------------------
CREATE OR REPLACE FILE FORMAT csv_format
    TYPE                         = 'CSV'
    SKIP_HEADER                  = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"';

CREATE OR REPLACE FILE FORMAT json_format
    TYPE              = 'JSON'
    STRIP_OUTER_ARRAY = TRUE;

-- -----------------------------------------------
-- Step 5. テーブル作成
--
-- ER 関係:
--   posts (N) --- (1) products (1) --- (N) daily_sales
--   posts (1) --- (1) image_features   ※ Part 1 ノートブックで作成
-- -----------------------------------------------

-- 商品マスタ(5件)
CREATE OR REPLACE TABLE products (
    product_id   VARCHAR(10) PRIMARY KEY COMMENT '商品ID',
    product_name VARCHAR(100)            COMMENT '商品名',
    category     VARCHAR(50)             COMMENT '商品カテゴリ(スーツケース/ポーチ/ネックピロー/充電器/パスポートケース)',
    price        NUMBER(10,0)            COMMENT '販売価格(円)',
    description  VARCHAR(500)            COMMENT '商品説明'
)
COMMENT = '旅行グッズブランドの商品マスタ';

-- インフルエンサー投稿(53件)
-- product_id は CSV では空欄。Step 6 で image_list を使って埋めます。
CREATE OR REPLACE TABLE posts (
    post_id    VARCHAR(10) PRIMARY KEY COMMENT '投稿ID',
    product_id VARCHAR(10)             COMMENT '投稿で紹介している商品ID',
    posted_at  TIMESTAMP               COMMENT '投稿日時',
    likes      NUMBER                  COMMENT 'いいね数',
    comments   NUMBER                  COMMENT 'コメント数',
    image_path VARCHAR(100)            COMMENT '投稿画像のファイル名(image_features との結合キー)'
)
COMMENT = 'インフルエンサーの SNS 投稿メタデータ';

-- 日別売上(305件)
CREATE OR REPLACE TABLE daily_sales (
    sale_date    DATE         COMMENT '売上日',
    product_id   VARCHAR(10)  COMMENT '商品ID',
    units_sold   NUMBER       COMMENT '販売数',
    sales_amount NUMBER(12,0) COMMENT '売上金額(円)'
)
COMMENT = '商品ごとの日別売上データ';

-- SNS 投稿(265件) ※ Part 1 の AI 関数デモ専用のサンプルデータ
--   Part 2 のインフルエンサー分析とは別シナリオ(EC サイトの SNS メンション)です。
--   AI_EXTRACT / AI_CLASSIFY の動作をテキストデータで体験するために用意しています。
CREATE OR REPLACE TABLE sns_mentions (
    post_id      VARCHAR(30) PRIMARY KEY COMMENT '投稿ID',
    platform     VARCHAR(20)             COMMENT 'プラットフォーム(instagram/twitter など)',
    post_type    VARCHAR(20)             COMMENT '投稿種別',
    username     VARCHAR(50)             COMMENT 'ユーザー名',
    display_name VARCHAR(100)            COMMENT '表示名',
    content      VARCHAR                 COMMENT '投稿本文(AI 関数の入力)',
    posted_at    TIMESTAMP               COMMENT '投稿日時',
    likes        NUMBER                  COMMENT 'いいね数',
    retweets     NUMBER                  COMMENT 'リポスト数',
    replies      NUMBER                  COMMENT '返信数',
    hashtags     ARRAY                   COMMENT 'ハッシュタグ'
)
COMMENT = 'Part 1 AI 関数デモ用の SNS 投稿サンプルデータ';

-- 商品マスタ(576件) ※ Part 1 の AI_SIMILARITY(名寄せ)デモ専用の別シナリオのサンプルデータです。
--   旅行グッズブランド(products テーブル)とは無関係の汎用EC商品カタログです。
CREATE OR REPLACE TABLE dim_products (
    product_id      VARCHAR PRIMARY KEY COMMENT '商品ID',
    product_name    VARCHAR             COMMENT '商品名',
    product_name_en VARCHAR             COMMENT '商品名(英語)',
    category_l1     VARCHAR             COMMENT 'カテゴリ1',
    category_l2     VARCHAR             COMMENT 'カテゴリ2',
    category_l3     VARCHAR             COMMENT 'カテゴリ3',
    brand           VARCHAR             COMMENT 'ブランド名',
    supplier_id     VARCHAR             COMMENT 'サプレID',
    cost_price      DECIMAL(10,2)       COMMENT '仕入価格',
    list_price      DECIMAL(10,2)       COMMENT '定価',
    current_price    DECIMAL(10,2)      COMMENT '現在の価格',
    stock_quantity  INTEGER             COMMENT '在庫数',
    product_status  VARCHAR             COMMENT '商品ステータス',
    launch_date     DATE                COMMENT '発売日',
    description     TEXT                COMMENT '商品説明',
    weight_g        INTEGER             COMMENT '重量(g)',
    dimensions      VARCHAR             COMMENT '寸法'
)
COMMENT = 'Part 1 AI_SIMILARITY(名寄せ)デモ用の汎用EC商品カタログ';

-- 仕入先商品リスト(50件程度) ※ 上記 dim_products と表記揺れを含んで突合する対話データ
CREATE OR REPLACE TABLE supplier_products_v2 (
    supplier_product_id   VARCHAR PRIMARY KEY COMMENT '仕入先商品ID',
    supplier_product_name VARCHAR             COMMENT '仕入先側の商品名(表記揺れあり)',
    supplier_name         VARCHAR             COMMENT '仕入先企業名',
    supplier_price        DECIMAL(10,2)       COMMENT '仕入先提示価格',
    supplier_category     VARCHAR             COMMENT '仕入先カテゴリ',
    original_product_id   VARCHAR             COMMENT '正解データ(結果検証用。dim_products.product_id を参照)'
)
COMMENT = 'Part 1 AI_SIMILARITY(名寄せ)デモ用の仕入先商品リスト';

-- -----------------------------------------------
-- Step 6. データロード + product_id の補完
-- -----------------------------------------------
COPY INTO products    FROM @DATA_STAGE/data/csv/products.csv    FILE_FORMAT = (FORMAT_NAME = csv_format);
COPY INTO posts       FROM @DATA_STAGE/data/csv/posts.csv       FILE_FORMAT = (FORMAT_NAME = csv_format);
COPY INTO daily_sales FROM @DATA_STAGE/data/csv/daily_sales.csv FILE_FORMAT = (FORMAT_NAME = csv_format);

-- AI_SIMILARITY(名寄せ)デモ用データ
COPY INTO dim_products         FROM @DATA_STAGE/data/csv/dim_products.csv         FILE_FORMAT = (FORMAT_NAME = csv_format);
COPY INTO supplier_products_v2 FROM @DATA_STAGE/data/csv/supplier_products_v2.csv FILE_FORMAT = (FORMAT_NAME = csv_format) ON_ERROR = 'CONTINUE';

-- SNS 投稿(JSON 配列を1行1レコードに展開してロード)
INSERT INTO sns_mentions (post_id, platform, post_type, username, display_name,
                          content, posted_at, likes, retweets, replies, hashtags)
SELECT
    $1:post_id::VARCHAR,
    $1:platform::VARCHAR,
    $1:post_type::VARCHAR,
    $1:username::VARCHAR,
    $1:display_name::VARCHAR,
    $1:content::VARCHAR,
    $1:posted_at::TIMESTAMP,
    $1:likes::NUMBER,
    $1:retweets::NUMBER,
    $1:replies::NUMBER,
    $1:hashtags::ARRAY
FROM @DATA_STAGE/data/json/sns_logs.json (FILE_FORMAT => json_format);

-- 画像 ↔ 商品ID の対応表(一時テーブル)
CREATE OR REPLACE TEMPORARY TABLE image_product_map (
    image_file VARCHAR(50),
    product_id VARCHAR(10)
);

COPY INTO image_product_map FROM @DATA_STAGE/data/csv/image_list.csv FILE_FORMAT = (FORMAT_NAME = csv_format);

-- posts.image_path(例: 'posts/post_001.jpg')と
-- image_list.image_file(例: 'post_001.jpg')を突合して product_id を埋める
UPDATE posts p
SET p.product_id = m.product_id
FROM image_product_map m
WHERE REPLACE(p.image_path, 'posts/', '') = m.image_file;

-- image_path を「ファイル名のみ」に正規化する
--   CSV上は 'posts/post_001.jpg' だが、image_features.image_file は 'post_001.jpg'。
--   Semantic View の RELATIONSHIP で両者を直接結合するため、ここで揃えておく。
--   (正規化しないと posts と image_features が結合できず、画像特徴量を絡めた質問に答えられない)
UPDATE posts
SET image_path = REPLACE(image_path, 'posts/', '');

-- -----------------------------------------------
-- Step 7. セットアップ確認
--
-- ※ image_features は Part 1 ノートブックの AI_COMPLETE セクションで作成します。
--
-- Run All で一括実行した場合、Snowsight は最後の1文の結果しか表示しません。
-- そのため確認クエリは1つにまとめています(RESULT列 = EXPECTED列であればOK)。
--
-- 件数が0や期待値と異なる場合は load.sql での Git 連携設定(リポジトリURL・
-- API_ALLOWED_PREFIXES 等)と、Step 3 の FETCH・COPY FILES が
-- 正常に実行されたかを確認してください。
-- -----------------------------------------------
SELECT 'products'               AS check_item, COUNT(*)::VARCHAR                    AS result, '5'   AS expected FROM products             UNION ALL
SELECT 'posts'                  AS check_item, COUNT(*)::VARCHAR                    AS result, '53'  AS expected FROM posts                UNION ALL
SELECT 'daily_sales'            AS check_item, COUNT(*)::VARCHAR                    AS result, '305' AS expected FROM daily_sales          UNION ALL
SELECT 'sns_mentions'           AS check_item, COUNT(*)::VARCHAR                    AS result, '265' AS expected FROM sns_mentions         UNION ALL
SELECT 'dim_products'           AS check_item, COUNT(*)::VARCHAR                    AS result, '576' AS expected FROM dim_products         UNION ALL
SELECT 'supplier_products_v2'   AS check_item, COUNT(*)::VARCHAR                    AS result, '100' AS expected FROM supplier_products_v2 UNION ALL
SELECT 'posts.null_product_id' AS check_item, (COUNT(*) - COUNT(product_id))::VARCHAR AS result, '0' AS expected FROM posts                UNION ALL
SELECT 'stage:POST_IMAGES(jpg)' AS check_item, COUNT(*)::VARCHAR                    AS result, '53'  AS expected FROM DIRECTORY(@POST_IMAGES) UNION ALL
SELECT 'stage:DATA_STAGE(all)'  AS check_item, COUNT(*)::VARCHAR                    AS result, '12'  AS expected FROM DIRECTORY(@DATA_STAGE)
ORDER BY check_item;

-- ※ posts と image_features の結合確認は Part 1 ノートブックで image_features 作成後に行います

-- =============================================================
-- クリーンアップはハンズオン終了後に cleanup.sql を実行してください
-- =============================================================
