# Snowflake Cortex AI ハンズオン 2026

Snowflake をある程度使っている方向けに、Cortex AI 機能を実際に手を動かして体験するハンズオン資材です。

## シナリオ

**旅行グッズブランドのマーケティング担当**として、インフルエンサー施策の効果を分析します。

SNS 投稿画像を AI で構造化し、売上データや商品スペックシート(PDF)と掛け合わせて、
**「どんな写真が売上に貢献するのか」**を Snowflake CoWork で自然言語分析します。

## 現在のステータス

| Part | 内容 | 状態 |
|---|---|---|
| **Part 1** | **Cortex AI 関数(ウェアハウス作成 + AI 関数)** | **作成済み(Dry-run 実施中)** |
| **Part 2** | **Snowflake CoWork** | **作成済み(Dry-run 完了)** |

> オープニング・CoCo・クロージングはスライドで実施するため、Notebook はありません。

> Part 2 の Cortex Search セクション(セクション5)で使う**商品スペックシート PDF は作成済み**です。
> 詳細は [data/pdf/README.md](data/pdf/README.md) を参照してください。

## ファイル構成

```
snowflake_ai_handson_2026/
├── README.md                        # このファイル
├── setup.sql                        # 環境構築(最初に実行、Part 1・2 共通)
├── cleanup.sql                      # 環境削除(ハンズオン終了後に実行)
├── part1_snowflake_basics_ai.ipynb  # Part 1 ハンズオン Notebook
├── part2_cowork.ipynb               # Part 2 ハンズオン Notebook
└── data/
    ├── csv/
    │   ├── products.csv              # 商品マスタ(5件)
    │   ├── posts.csv                 # SNS投稿(53件)
    │   ├── daily_sales.csv           # 日別売上(305件)
    │   ├── image_list.csv            # 画像↔商品ID対応(53件)
    │   ├── dim_products.csv          # 商品マスタ(576件、AI_SIMILARITY名寄せ用・別シナリオ)
    │   └── supplier_products_v2.csv  # 仕入先商品リスト(100件、AI_SIMILARITY名寄せ用)
    ├── json/
    │   └── sns_logs.json    # SNS投稿サンプル(265件、Part 1 AI関数デモ用)
    ├── images/              # 投稿画像(53枚)
    ├── pdf/                 # 商品スペックシートPDF(5商品分)
    └── slide/               # Notebook内に埋め込むAI関数解説画像
```

## 事前準備

### 1. このリポジトリをダウンロード

GitHub の **「Code」→「Download ZIP」** で一括ダウンロードして展開します。

```
https://github.com/hilasnow/snowflake_ai_handson_2026
```

### 2. Snowsight でワークスペースを作成

**Projects → Workspaces** から新規ワークスペースを作成します。

> ⚠️ ワークスペース名は必ず **`snowflake_ai_handson_2026`** にしてください。
> `setup.sql` の `COPY FILES` がこの名前を参照しているため、別の名前にすると失敗します。

### 3. ファイルをアップロード

ワークスペースの **「+ 新規追加」→「ファイルをアップロード」** から、展開した ZIP 内の全ファイルをアップロードします。

- `setup.sql`
- `cleanup.sql`
- `part1_snowflake_basics_ai.ipynb`
- `part2_cowork.ipynb`
- `data/` フォルダ配下すべて(CSV・JSON・画像・PDF)

### 4. setup.sql を実行

`setup.sql` を開いて全体を選択し、一括実行します。

作成されるオブジェクト:

| 種類 | 名前 |
|---|---|
| ウェアハウス | `AI_HANDSON_WH` (XSMALL) |
| データベース | `AI_HANDSON_DB` |
| スキーマ | `ANALYTICS` |
| ステージ | `DATA_STAGE`(CSV・PDF用)、`POST_IMAGES`(画像用) |
| テーブル | `products`, `posts`, `daily_sales`, `sns_mentions`, `dim_products`, `supplier_products_v2` |

> `image_features`(投稿画像53枚を `AI_COMPLETE` で構造化したテーブル)は、
> Part 1 の `AI_COMPLETE` セクションでハンズオン中に作成します。

### 5. 実行結果を確認

`setup.sql` 末尾の確認クエリで、以下の件数になっていることを確認します。

| テーブル | 期待件数 |
|---|---|
| `products` | 5 |
| `posts` | 53 |
| `daily_sales` | 305 |
| `sns_mentions` | 265 |
| `dim_products` | 576 |
| `supplier_products_v2` | 100 |

件数が 0 の場合は、ワークスペース名が `snowflake_ai_handson_2026` になっているか確認してください。

## ハンズオンの進め方

`part1_snowflake_basics_ai.ipynb` → `part2_cowork.ipynb` の順に進めます。

### Part 1 : Cortex AI 関数(約 30 分)

| # | 内容 |
|---|---|
| 1 | ウェアハウスの作成(アダプティブウェアハウスを SQL で作成、GUI での作成方法も紹介) |
| 2 | `AI_EXTRACT` — テキストから項目を構造化して抽出 + **PDF** から抽出 |
| 3 | `AI_CLASSIFY` — テキストを指定カテゴリに分類して集計 |
| 4 | `AI_COMPLETE` — **画像**を分析して構造化(3枚デモ → 53枚全件で `image_features` を作成) |
| 5 | `AI_SIMILARITY` — 名寄せ(表記揺れのある商品リストを意味的類似度で突合) |

> セクション 1 で作成した `AI_HANDSON_ADAPTIVE_WH` を、**セクション 2 以降と Part 2 でもそのまま使います**。

> セクション 2・3 の `sns_mentions` は AI 関数の動きを見るための**別シナリオのサンプルデータ**です。

> セクション 4 の `image_features`(53枚全件)の作成は数分かかります。
> このテーブルは Part 2 の分析対象になるため、**Part 1 を実行してから Part 2 に進んでください**。

> セクション 5 の `dim_products` / `supplier_products_v2` も、旅行グッズブランドとは無関係の
> **別の汎用EC商品カタログ**です。AI_SIMILARITY の挙動を確認するためのサンプルデータとして扱ってください。

> ステージからのデータ取り込み(`COPY INTO`)は `setup.sql` で実施済みのため、
> Notebook では扱わずスライドで説明します。

### Part 2 : Snowflake CoWork(約 65 分)

| # | 内容 | 想定時間 |
|---|---|---|
| 1 | データ確認 | (2 に含む) |
| 2 | Agent 作成 + Semantic View **Before** 版 | 5分 |
| 3 | CoWork で質問して限界を体験する | (2 に含む) |
| 4 | Semantic View **After** 版に改善する | 15分 |
| 5 | PDF から Cortex Search を構築する | 15分 |
| 6 | 構造化 + 非構造化を横断する質問 | 10分 |
| 7 | Artifacts | 5分 |
| 8 | Document generation + コード実行ツール | 10分 |
| 9 | Automations | 5分 |

> 時間配分は暫定です。Dryrun 後に調整予定です。

## 必要な権限・前提

- ロール: `ACCOUNTADMIN`(Agent 作成、`CORTEX_ENABLED_CROSS_REGION` 設定に必要)
- Cortex AI 機能が有効なアカウント
- クロスリージョン推論の有効化(`setup.sql` の Step 1 で設定)

## 使用する機能のリリース状況

| 機能 | 状況 |
|---|---|
| アダプティブウェアハウス | GA(Enterprise Edition 以上・対応リージョンのみ) |
| AI 関数(AI_EXTRACT / AI_CLASSIFY / AI_COMPLETE) | GA |
| Snowflake CoWork | GA |
| Cortex Analyst / Semantic View | GA |
| Cortex Search | GA |
| Artifacts | GA(2026/6/17) |
| Document generation | Preview |
| Cortex Agent コード実行ツール | Public Preview(2026/8/20) |
| Automations | Public Preview(2026/8/6) |

## クリーンアップ

ハンズオン後に環境を削除する場合は、`cleanup.sql` を開いて全体を選択し、一括実行してください。
Part 1・Part 2 で作成したオブジェクト(アダプティブウェアハウス、Semantic View、Cortex Search Service など)と
`setup.sql` で作成した共通オブジェクト(データベース・ウェアハウス)をまとめて削除します。

Agent(`MARKETING_AGENT`)は Snowsight の **「AI と ML」→「エージェント」** から手動で削除します。
