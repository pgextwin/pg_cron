# pg_cron Windows x64 バイナリ利用ガイド

この文書は、pgextwinが配布する **非公式 pg_cron Windows x64バイナリ**を、一般的なWindows版PostgreSQLへ導入するための補足ガイドです。

pg_cron本体の機能、SQL API、設定パラメータ、権限、制限事項については [pg_cron公式README](https://github.com/citusdata/pg_cron/blob/v1.6.8/README.md) を正規の情報源としてください。

## 対応環境

- OS: Windows x64
- pg_cron upstream release: 1.6.8
- 使用ソースtag: `v1.6.8`
- PostgreSQL: READMEに記載したメンテナンス対象メジャー
- Compiler: MSVC

**PostgreSQLのメジャーバージョンが異なるZIPは使用しないでください。**

例としてPostgreSQL 18には:

~~~text
pg_cron-v1.6.8-pg18-windows-x64.zip
~~~

を使用します。

## ZIPの内容

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

## 1. PostgreSQLを停止

DLLを配置・更新する前にPostgreSQLを停止します。

Windowsサービスとして稼働している場合は、現在の運用手順に従ってサービスを安全に停止してください。

## 2. ZIPを展開してファイルを配置

一般的なEDB PostgreSQL Installerでは、例えばPostgreSQL 18のインストール先は次のようになります。

~~~text
C:\Program Files\PostgreSQL\18\
~~~

配置先:

~~~text
ZIP\lib\pg_cron.dll
  -> C:\Program Files\PostgreSQL\18\lib\pg_cron.dll

ZIP\share\extension\pg_cron.control
ZIP\share\extension\pg_cron--*.sql
  -> C:\Program Files\PostgreSQL\18\share\extension\
~~~

`Program Files` 配下へコピーするため、Windowsの管理者権限が必要になる場合があります。

## 3. shared_preload_librariesを設定

pg_cronはbackground workerを起動するため、`postgresql.conf` の `shared_preload_libraries` へ追加する必要があります。

~~~conf
shared_preload_libraries = 'pg_cron'
~~~

既に他のextensionを設定している場合は、既存値を消さずPostgreSQLのリスト形式で `pg_cron` を追加してください。

例:

~~~conf
shared_preload_libraries = 'pg_stat_statements,pg_cron'
~~~

変更後はPostgreSQLの再起動が必要です。

## 4. metadata databaseを決める

pg_cronのmetadata tableはcluster内の1 databaseだけに作成されます。初期値は `postgres` です。

~~~conf
cron.database_name = 'postgres'
~~~

別databaseを使う場合は、PostgreSQL起動前に設定してください。

pg_cronは1つのclusterにつき1 databaseにだけインストールできます。他databaseでjobを実行したい場合は、公式の `cron.schedule_in_database()` を使用します。

## 5. job実行方法を選ぶ

### 標準: libpq接続

標準ではpg_cronがlocalhostへ新しいPostgreSQL接続を作成します。

そのため、jobを実行するuserについて:

- `pg_hba.conf` で接続が許可されていること
- password認証の場合は適切なpassword/`.pgpass` が利用できること

が必要です。

認証方式を安易に弱めないでください。実運用のセキュリティ方針に合わせて設定してください。

### background worker

libpq接続を使わずPostgreSQL background workerとしてjobを実行することもできます。

~~~conf
cron.use_background_workers = on
~~~

この場合、同時実行数は `max_worker_processes` の制約を受けます。

例:

~~~conf
max_worker_processes = 20
cron.use_background_workers = on
~~~

pgextwinのCIでは、このbackground-worker modeを使って実際のscheduled job実行を検証しています。

## 6. timezone

pg_cronのschedule timezoneは `cron.timezone` で設定できます。

日本時間を利用する例:

~~~conf
cron.timezone = 'Asia/Tokyo'
~~~

設定可能値や挙動はupstreamドキュメントとPostgreSQL timezone設定を確認してください。

## 7. PostgreSQLを起動してExtensionを作成

PostgreSQLを起動し、`cron.database_name` で設定したdatabaseへ接続して実行します。

~~~sql
CREATE EXTENSION pg_cron;
~~~

psqlで確認する場合:

~~~text
\dx pg_cron
~~~

## 8. 基本動作確認

1分ごとに `SELECT 1` を実行する例:

~~~sql
SELECT cron.schedule(
    'pgextwin-test',
    '* * * * *',
    'SELECT 1'
);
~~~

job一覧:

~~~sql
SELECT jobid, jobname, schedule, command, active
FROM cron.job
ORDER BY jobid;
~~~

jobを削除:

~~~sql
SELECT cron.unschedule('pgextwin-test');
~~~

pg_cron 1.6系では1〜59秒間隔も利用できます。例えば:

~~~sql
SELECT cron.schedule(
    'pgextwin-10sec-test',
    '10 seconds',
    'SELECT 1'
);
~~~

確認後は不要なjobを削除してください。

## job実行履歴

標準では `cron.job_run_details` へ実行結果が記録されます。

~~~sql
SELECT *
FROM cron.job_run_details
ORDER BY start_time DESC
LIMIT 20;
~~~

高頻度jobでは履歴が増えるため、運用上必要な保持期間を決めてください。公式READMEにはpg_cron自身で古い履歴を削除する例もあります。

## PostgreSQL 14/15について

pg_cron v1.6.8のupstream Windows buildは新しいPostgreSQLで動作しますが、PG14/15ではWindows DLL export仕様の差があります。

pgextwinのPG14/15 packageは、upstream Cソースを変更せず、ビルド時に必要symbolをDEFファイルで明示exportして作成しています。

PG14/15についてもCIで:

- PostgreSQL起動
- `shared_preload_libraries=pg_cron`
- `CREATE EXTENSION pg_cron`
- 1秒job登録
- 実際のINSERT実行

まで確認しています。

PG16以降はupstreamの `Makefile.win` をそのまま使用します。

## 更新

### PostgreSQLマイナー更新

同じmajor内でも、pgextwin Releaseがどのminorで検証されたかをREADMEと `PACKAGE-INFO.txt` で確認してください。

### PostgreSQLメジャー更新

例えばPG17からPG18へ更新する場合、PG18専用ZIPを使用してください。PG17用 `pg_cron.dll` を流用しないでください。

### pg_cron更新

upstream pg_cronを更新する場合、extension SQL upgrade scriptとupstream CHANGELOGを確認してください。

## アンインストール

まずmetadata databaseで、必要なjobと依存関係を確認してから:

~~~sql
DROP EXTENSION pg_cron;
~~~

を実行します。

その後PostgreSQLを停止し、必要に応じて:

~~~text
<PostgreSQL>\lib\pg_cron.dll
<PostgreSQL>\share\extension\pg_cron.control
<PostgreSQL>\share\extension\pg_cron--*.sql
~~~

を削除し、`postgresql.conf` の `shared_preload_libraries` と `cron.*` 設定を整理します。

## 公式ドキュメント

- pg_cron repository: https://github.com/citusdata/pg_cron
- pg_cron v1.6.8 README: https://github.com/citusdata/pg_cron/blob/v1.6.8/README.md
- pg_cron v1.6.8 CHANGELOG: https://github.com/citusdata/pg_cron/blob/v1.6.8/CHANGELOG.md

この文書とupstreamドキュメントに差異がある場合、pg_cron本体の仕様についてはupstreamドキュメントを優先してください。
