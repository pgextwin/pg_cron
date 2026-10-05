# pg_cron Windows バイナリ

[English](README.md) | **日本語**

このリポジトリでは、[pg_cron](https://github.com/citusdata/pg_cron) の **非公式 Windows x64 バイナリ**を提供します。

pg_cronはPostgreSQL内で動作するcronベースのジョブスケジューラです。pg_cron本体の機能、SQL API、設定パラメータ、制限事項、セキュリティ仕様については、**pg_cron公式ドキュメントを正規の情報源**としてください。

## 公式情報

- 公式リポジトリ: https://github.com/citusdata/pg_cron
- 使用する公式ソース: **v1.6.8**
- 固定upstream commit: **5cedfa472ccc83567aa23ec645925ed8489a7797**
- ライセンス: upstreamと同一のPostgreSQL-style permissive license
- native Windows build support: upstream **v1.6.8** で追加
- 公式README: https://github.com/citusdata/pg_cron/blob/v1.6.8/README.md
- 公式CHANGELOG: https://github.com/citusdata/pg_cron/blob/v1.6.8/CHANGELOG.md

CI/CDでは固定した公式tagをcheckoutしてビルドします。このリポジトリにはpg_cron本体のCソースをforkしたコピーは保持しません。

## ドキュメント

- [Windows x64 バイナリ利用ガイド](docs/windows_ja.md)
- [English README](README.md)

Windows固有の配置方法やpgextwinのパッケージ構成はこのリポジトリを参照してください。pg_cronの機能仕様や設定値は公式READMEを優先してください。

## 対応PostgreSQLバージョン

Windowsバイナリは、ビルド日時点でPostgreSQLコミュニティのメンテナンス対象であるメジャーバージョンを対象にします。

2026-10-06時点:

| PostgreSQL | 動作確認マイナーバージョン | コミュニティEOL |
|---|---:|---:|
| 14 | 14.24 | 2026-11-12 |
| 15 | 15.19 | 2027-11-11 |
| 16 | 16.15 | 2028-11-09 |
| 17 | 17.11 | 2029-11-08 |
| 18 | 18.6 | 2030-11-14 |

PostgreSQLのライフサイクル情報は **pgextwin/build** で一元管理し、このリポジトリでは [config/extension.json](config/extension.json) にpg_cronの対応範囲を定義します。PostgreSQL 14は現在対象ですが、設定済みEOL日を過ぎると共通workflowから自動的に除外されます。

配布対象は **Windows x64のみ**です。

## ダウンロード

このリポジトリの **Releases** から、使用しているPostgreSQLメジャーバージョンに一致するZIPをダウンロードします。

例:

~~~text
pg_cron-v1.6.8-pg18-windows-x64.zip
~~~

ZIPの主な内容:

~~~text
lib/
  pg_cron.dll
share/
  extension/
    pg_cron.control
    pg_cron--1.0.sql
    pg_cron--*--*.sql
LICENSE
UPSTREAM-README.md
UPSTREAM-CHANGELOG.md
PACKAGE-INFO.txt
~~~

## インストール

詳細は [Windows x64 バイナリ利用ガイド](docs/windows_ja.md) を参照してください。基本手順は次のとおりです。

1. PostgreSQLを停止します。
2. PostgreSQLメジャーバージョンに一致するZIPを展開します。
3. `lib/pg_cron.dll` をPostgreSQLの `lib` へコピーします。
4. `share/extension/` 以下をPostgreSQLの `share/extension` へコピーします。
5. `postgresql.conf` の `shared_preload_libraries` に `pg_cron` を追加します。
6. 必要に応じて `cron.database_name`、`cron.timezone`、`cron.use_background_workers` 等を設定します。
7. PostgreSQLを再起動します。
8. `cron.database_name` で指定したデータベースで次を実行します。

~~~sql
CREATE EXTENSION pg_cron;
~~~

pg_cronは1つのPostgreSQL clusterにつき1つのdatabaseにだけインストールできます。他databaseのjobは公式の `cron.schedule_in_database()` を利用します。

標準設定ではpg_cronがlibpqでローカル接続を作成するため、`pg_hba.conf` やpassword/`.pgpass` の設定が必要です。代わりにbackground workerを利用する場合は:

~~~conf
cron.use_background_workers = on
~~~

を設定します。その場合は `max_worker_processes` に十分な余裕を確保してください。

## PostgreSQL 14/15 Windows互換処理

pg_cron v1.6.8でnative Windows build supportが公式に追加されました。

ただしWindowsにおけるPostgreSQL headerの仕様がPG14/15とPG16以降で異なり、PG14/15では `PG_FUNCTION_INFO_V1()` がSQL-callable関数本体をDLL exportしません。PG16以降では自動exportされます。

そのためpgextwinではPG14/15だけ、ビルド時に次の互換処理を行います。

1. upstream Cソースから `PG_FUNCTION_INFO_V1(...)` 宣言を検出
2. 一時的なDEFファイルを生成
3. `_PG_init` とSQL-callable関数をexport
4. upstream `Makefile.win` の一時コピーへlinkerの `/DEF` 指定を追加

upstream Cソースそのものは変更しません。PG16〜18では公式 `Makefile.win` を無変更で使用します。

この互換処理はPG14/15の両方で、`CREATE EXTENSION pg_cron` に加えて1秒間隔のscheduled jobを実際に実行するところまで検証済みです。

## CI/CD

[.github/workflows/windows.yml](.github/workflows/windows.yml) は共通処理を **pgextwin/build** のReusable Workflowへ委譲します。

各PostgreSQLメジャーについて:

1. 中央metadataからメンテナンス対象を解決
2. pg_cron v1.6.8をcheckout
3. LICENSEをupstreamと照合
4. 対象PostgreSQL Windows x64を導入
5. `windows/ci/` のExtension固有hookを実行
6. MSVC/nmakeでビルド
7. `shared_preload_libraries=pg_cron` で一時PostgreSQLを起動
8. `CREATE EXTENSION pg_cron`
9. 1秒scheduled jobを登録し、実際にINSERTされることを確認
10. PostgreSQLメジャー別ZIPをartifact化

Pull Requestと `main` へのpushではCIのみを実行します。

GitHub Releaseを公開するときは、対象 `main` commitから次のbranchを作成します。

~~~text
release/<release-tag>
~~~

初回想定:

~~~text
release/v1.6.8-windows.1
~~~

全PostgreSQL matrixがPASSした場合だけ、ZIP 5個と `SHA256SUMS.txt` を含むReleaseを公開します。Release本文はEnglishを上、日本語を下にします。

## ライセンス

このリポジトリはupstream pg_cronと同一のライセンス本文を使用します。[LICENSE](LICENSE) を参照してください。

Release ZIP内の `LICENSE` は固定したupstream checkoutから直接コピーします。

このリポジトリが配布するWindowsバイナリはpgextwinによる非公式buildであり、upstream pg_cronの公式Windowsバイナリ配布ではありません。
