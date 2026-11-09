# pg_cron — Windows x64 バイナリ

[English](README.md) | 日本語

[pg_cron](https://github.com/citusdata/pg_cron)の**非公式Windows x64バイナリ**です。PostgreSQL内でSQLジョブを定期実行します。

## ダウンロードと対応環境

[最新の公開Release](https://github.com/pgextwin/pg_cron/releases/latest)から、利用中のPostgreSQLメジャーバージョンに一致するZIPを選んでください。[過去のReleases](https://github.com/pgextwin/pg_cron/releases)も確認できます。PostgreSQL **14〜18**向けの配布状況は[pgextwinカタログ](https://pgextwin.github.io/website/ja/)に掲載しています。PostgreSQL 14のコミュニティサポートは2026年11月12日に終了します。

## インストール

1. バックアップを取得し、[上流ドキュメント](https://github.com/citusdata/pg_cron)で必要条件を確認します。
2. ファイルを置き換える前にPostgreSQLを停止します。対応するZIPのlib/とshare/extension/以下のファイルを、PostgreSQLの同名ディレクトリに配置します。
3. `postgresql.conf`の`shared_preload_libraries`にpg_cronを追加し、`cron.database_name`で拡張機能を導入するデータベースを指定します。ジョブ実行時の接続認証やバックグラウンドワーカーの設定は上流ドキュメントを確認してください。
4. 設定を反映してPostgreSQLを起動し、利用するデータベースで`CREATE EXTENSION pg_cron;`を実行します。稼働中のPostgreSQLで事前ロード設定を変更した場合は、再起動が必要です。

ダウンロードしたファイルを、Releaseに掲載された`SHA256SUMS.txt`と照合してください。SPDX形式のSBOM、脆弱性レポート、署名付き証明の有無はReleaseで確認できます。本番環境に導入する前に、検証環境で動作を確認してください。

## ライセンス

機能、設定、制限事項は[上流のpg_cron](https://github.com/citusdata/pg_cron)を参照してください。本配布は非公式のWindowsバイナリです。ライセンスは同梱の表示に従います。
