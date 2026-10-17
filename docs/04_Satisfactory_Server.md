# Satisfactory Dedicated Server

## 1. 採用イメージ

CICD-ENVでは、次のDockerイメージを採用する。

```text
wolveix/satisfactory-server:latest
```

### 採用理由

- Satisfactory 1.1以降で必要な`7777/tcp`、`7777/udp`、`8888/tcp`に対応している
- `/config`配下にゲームファイル、セーブデータ、設定、ログ、バックアップを集約できる
- `SKIPUPDATE`で起動時の自動更新を制御できる
- Docker HubとGitHubで継続的な更新が確認できる
- ComposeのBind Mountと相性がよく、コンテナ再作成時もデータを保持できる

### イメージ名の改名について

GitHub上の確認では、メンテナーのユーザー名が`wolveix`から`robtme`へ改名されており、現在の公式イメージ名は`robtme/satisfactory-server`（`ghcr.io/robtme/satisfactory-server`も提供）である。READMEには、旧名`wolveix/satisfactory-server`も更新を受け続けるため既存環境は壊れない、と記載されている。

現時点では、動作確認前に構成を変えないため旧名`wolveix/satisfactory-server:latest`を使用する。`robtme`への移行は、手動で正常稼働を確認した後に判断する（「11. 未確認事項と判断待ち」を参照）。

`didstopia/satisfactory-server`は、確認できたDocker Hub説明が古いポート構成のままであるため、正式採用しない。
`indifferentbroccoli/satisfactory-server-docker`は更新が活発だが、最低RAM 12GBと記載されており、利用可能メモリ約10GBのCICD-ENV環境には適さない。

## 2. 永続化方針

コンテナ内部へゲームデータを保存しない。ホスト側では次の構成を使用する。

```text
CICD-ENV/
├── data/
│   └── satisfactory/
│       ├── backups/
│       ├── gamefiles/
│       └── saved/
└── logs/
    └── satisfactory/
```

`data/satisfactory`はコンテナの`/config`へBind Mountする。`saved`にはセーブデータ、サーバー設定、ブループリントが保存される。`gamefiles`はサーバー本体であり、コンテナ再作成後の再ダウンロードを避けるため保持する。`backups`はイメージが作成する自動バックアップ用である。

ログは`logs/satisfactory`を`/config/logs`へ個別にBind Mountする。

### パス指定の注意

ComposeのBind Mountの相対パスは、Composeファイル（`compose/docker-compose.yml`）のあるフォルダが基準になる。そのため、ホスト側は`../data/satisfactory`と書く。`./data/...`と書くと`compose/data/...`を指してしまう。`data/`と`logs/`はGit管理対象外（`.gitignore`で除外済み）である。

`docker compose config`で、ホスト側がリポジトリ直下の`data/satisfactory`と`logs/satisfactory`に解決されることを確認済み。

### Windows側フォルダのBind Mountについて

プロジェクトフォルダはWindows側（`C:\workspace\CICD-env`）にある。Windows側フォルダをBind Mountすると、`PUID`/`PGID`の権限処理やI/O速度に問題が出る可能性がある。初回起動時に確認し、問題があればWSL2内への配置を検討する。

## 3. ポート

| 用途 | ホスト | コンテナ | プロトコル |
|---|---:|---:|---|
| Game Server | 7777 | 7777 | TCP/UDP |
| Reliable Messaging | 8888 | 8888 | TCP |

旧構成で候補になっていた`15000/udp`と`15777/udp`は、今回採用するイメージの標準Compose構成には使用しない。

## 4. Compose設定

```yaml
name: cicd-env

services:
  satisfactory:
    image: wolveix/satisfactory-server:latest
    container_name: cicd-env-satisfactory
    restart: unless-stopped
    stop_grace_period: 90s
    ports:
      - "7777:7777/tcp"
      - "7777:7777/udp"
      - "8888:8888/tcp"
    volumes:
      - ../data/satisfactory:/config
      - ../logs/satisfactory:/config/logs
```

実際の正式設定は`compose/docker-compose.yml`を参照する。

### イメージタグとオートセーブ世代数

- イメージタグは`.env`の`SATISFACTORY_IMAGE_TAG`で切り替える（未設定時は`latest`）。CI/CD導入前に`v1.9.11`などのバージョンへ固定する
- オートセーブの保持世代数は`.env`の`SATISFACTORY_AUTOSAVENUM`（`AUTOSAVENUM`）で指定する（未設定時は5）

### リソース制限と停止設定

| 設定 | 値 | 理由 |
|---|---|---|
| メモリ上限 | 8G | 利用可能メモリ約10GBのうち、ホストとWSL2用の余裕を残す |
| メモリ予約 | 4G | サーバーが最低限確保すべき量 |
| `stop_grace_period` | 90s | 停止要求から強制終了までの待ち時間。停止時のセーブ時間を確保する |
| `restart` | `unless-stopped` | 異常終了時は再起動し、手動停止後は再起動しない |

`stop_grace_period`はセーブの間隔ではなく、停止要求から強制終了（SIGKILL）までの待ち時間である。ワールドが大きいと30sではセーブが間に合わない恐れがあるため、90sとした。通常の停止が早く終わる場合、停止時間は変わらない。

ヘルスチェックはComposeでは定義していない。イメージ自身が`healthcheck.sh`を持つため、挙動を確認する前に上書きしない。

## 5. 起動前の確認

Docker Desktopのメモリ割り当てを確認する。イメージの推奨値は4GB以上の予約、最大8GB程度である。ホストの利用可能メモリが約10GBのため、他のアプリケーションを終了してから起動する。

初回起動時はゲームファイルのダウンロードに時間がかかる。WSL2上のBind MountではI/Oが遅くなる場合があるため、ログが進行している間はすぐに停止しない。

## 6. 標準コマンド

```powershell
docker compose --env-file .env -f compose/docker-compose.yml config
docker compose --env-file .env -f compose/docker-compose.yml pull
docker compose --env-file .env -f compose/docker-compose.yml up -d
docker compose --env-file .env -f compose/docker-compose.yml ps
docker compose --env-file .env -f compose/docker-compose.yml logs -f satisfactory
```

初回は`config`で設定を確認し、問題がなければ`pull`、`up -d`の順に実行する。

## 7. 停止方法

```powershell
docker compose --env-file .env -f compose/docker-compose.yml stop satisfactory
```

Satisfactoryのコンソールで`quit`を実行して保存してから停止するのが基本である。`docker compose down -v`は永続データを削除する可能性があるため、検証中も不用意に実行しない。

## 8. 更新方針

自動更新をいきなりCI/CD化しない。初期検証では`SKIPUPDATE=false`のまま起動時更新を確認するが、本番更新手順は次の順序を守る。

1. サーバーを正常停止する
2. `data/satisfactory`をバックアップする
3. `docker compose pull`を実行する
4. コンテナを再作成する
5. ログ、ポート、ゲーム接続を確認する

バックアップに失敗した場合は、更新へ進まない。具体的な世代管理・リストア手順は`docs/05_Backup.md`で定義する。

### 更新運用の注意

このイメージは、`SKIPUPDATE=false`（既定）のとき、コンテナの起動・再起動のたびにゲーム本体を自動更新する。これは「更新前にバックアップを取り、失敗したら更新しない」という本プロジェクトの方針と衝突する。

- 将来のCI/CD導入時に、`SKIPUPDATE=true`にして更新を明示的な手順に分離することを検討する
- 現時点では既定（`SKIPUPDATE=false`）のままにする（`.env`の`SKIPUPDATE`で制御する）
- タスクスケジューラによる`docker compose up -d`の定期実行でも、コンテナが再作成されると更新が走る可能性がある点に注意する

## 9. 初期検証チェックリスト

- [x] Compose configが成功する
- [x] コンテナが起動する
- [x] ゲームファイルのダウンロードが完了する（約2.7GB）
- [x] ポート`7777/tcp`、`7777/udp`、`8888/tcp`が公開される
- [x] ゲームクライアントから接続できる（別PCから、Server Manager経由）
- [x] セーブデータが`data/satisfactory/saved`に保存される
- [x] コンテナ再作成後もセーブデータが残る（ファイルの保持を確認。再作成後のゲーム内の読み込みは未確認）
- [ ] 手動停止後に意図せず再起動しない
- [ ] Docker Desktop再起動後に復旧する

### 初回起動で確認した事項（2026-10-17）

- WSL2のメモリを既定のままにすると約7.2GBしか使えず、Composeの上限8Gが効かない。`C:\Users\<ユーザー名>\.wslconfig`に`memory=10GB`、`swap=4GB`を設定した
- コンテナの起動直後に`steamcmd`が`ERROR! Failed to install app '1690800' (Missing configuration)`で失敗し、コンテナが1回再起動する。再起動後は自動で復旧し、`healthy`になる。初回起動と、コンテナ再作成後の起動の両方で同じ挙動を確認した。ゲームファイルの再ダウンロード（全体）は発生しない
- ログに大量に出る`LogStringTable: Warning: Failed to find string table entry`は無視してよい
- ゲームクライアントで「Join Game」などの直接入力から接続すると、`Encryption token missing`が表示される。Server Managerの「Add Server」から追加する
- `docker compose down`（`-v`なし）は約2秒で完了した。コンテナ再作成でも`data/satisfactory`のゲームファイルとセーブデータは残る
- 起動確認の前にあった旧nginxの孤立コンテナ`cicd-env-test`は削除した

## 10. 参照情報

- Docker Hub: <https://hub.docker.com/r/wolveix/satisfactory-server>
- GitHub: <https://github.com/wolveix/satisfactory-server>
- Satisfactory Dedicated Server Wiki: <https://satisfactory.wiki.gg/wiki/Dedicated_servers>
- 改名後のDocker Hub: <https://hub.docker.com/r/robtme/satisfactory-server>

## 11. 未確認事項と判断待ち

2026-10-17時点の調査結果。確認できなかった項目は推測で埋めず「未確認」とする。

| 項目 | 結果 |
|---|---|
| イメージのライセンス | MIT License（Copyright (c) 2021 Robert Thomas）。GitHubの`LICENSE`で確認 |
| `healthcheck.sh`の挙動 | `https://127.0.0.1:${SERVERGAMEPORT}/api/v1`へ`HealthCheck`をPOSTし、`jq`で`.data.health == "healthy"`を判定する。`SERVERGAMEPORT`が未設定だと正しく動かない可能性があるため、Composeで`SERVERGAMEPORT`を渡している現構成を維持する |
| 最新のSatisfactory本体バージョンへの対応 | 未確認。READMEに対応バージョンの記載がなかった |
| イメージの最新バージョンタグ | `robtme/satisfactory-server`のDocker Hubに`v1.9.11`が確認できた（`latest`と同時期の更新）。一部のページ（3ページ中1ページ目）のみ確認。`wolveix/satisfactory-server`側のタグは未確認 |
| イメージの改名 | `wolveix`から`robtme`へ改名済み。旧名も更新を受け続けると記載あり |

### 判断待ち

- `robtme/satisfactory-server`へ移行するか（手動で正常稼働を確認した後に判断する）
- CI/CD導入前に、バージョンタグ（例: `v1.9.11`）へ固定するか
- `SKIPUPDATE=true`への切り替え時期
