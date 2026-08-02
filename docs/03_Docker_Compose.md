# Docker Compose基盤構築手順書

## 1. 目的

本手順では、CICD-ENVプロジェクトにDocker Composeの基盤を構築する。

今回の目的は以下のとおり。

- Docker Compose V2を利用する
- `.env`による環境設定を利用する
- Docker Networkを定義する
- Docker Volumeを定義する
- Healthcheckを定義する
- Docker Composeによる起動・停止を確認する

この段階ではSatisfactory Serverは導入しない。

---

## 2. 前提環境

| 項目 | 内容 |
|---|---|
| OS | Windows 11 Home |
| WSL | WSL2 |
| Linux | Ubuntu 24.04 LTS |
| Docker | Docker Desktop |
| Compose | Docker Compose V2 |
| プロジェクト | CICD-ENV |

---

## 3. 構成

```text
CICD-ENV/
│
├── compose/
│   └── docker-compose.yml
│
├── config/
├── data/
├── logs/
│
├── scripts/
│   ├── backup/
│   ├── restore/
│   ├── deploy/
│   └── maintenance/
│
├── docs/
│
├── .env
├── .env.example
├── .gitignore
└── README.md
```

---

## 4. 環境変数

### `.env`

以下を設定する。

```dotenv
TZ=Asia/Tokyo

GAME_SERVER_NAME=CICD-ENV
```

`COMPOSE_PROJECT_NAME`は使用しない。

Docker Composeのプロジェクト名は`docker-compose.yml`側で固定する。

---

## 5. Docker Composeファイル

`compose/docker-compose.yml`を作成する。

正式版：

```yaml
name: cicd-env

services:

  test:
    image: nginx:alpine

    container_name: cicd-env-test

    restart: "no"

    environment:
      TZ: ${TZ}

    volumes:
      - test-data:/usr/share/nginx/html

    networks:
      - cicd-env-network

    healthcheck:
      test:
        [
          "CMD",
          "wget",
          "--no-verbose",
          "--tries=1",
          "--spider",
          "http://127.0.0.1/"
        ]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s


networks:

  cicd-env-network:
    name: cicd-env-network
    driver: bridge


volumes:

  test-data:
    name: cicd-env-test-data
```

---

## 6. Composeプロジェクト名

Composeプロジェクト名は以下で固定する。

```text
cicd-env
```

```yaml
name: cicd-env
```

環境変数`COMPOSE_PROJECT_NAME`は使用しない。

これにより、`.env`の読み込み状態によってComposeプロジェクト名が空になる問題を防止する。

---

## 7. `.env`の読み込み

CICD-ENVでは、Compose実行時に`.env`を明示的に指定する。

基本形式：

```powershell
docker compose --env-file .env -f compose/docker-compose.yml
```

以降のCompose操作ではこの形式を標準とする。

---

## 8. Composeファイル検証

以下を実行する。

```powershell
docker compose --env-file .env -f compose/docker-compose.yml config
```

エラーがなければComposeファイルの構文は正常。

---

## 9. コンテナ起動

```powershell
docker compose --env-file .env -f compose/docker-compose.yml up -d
```

---

## 10. コンテナ状態確認

```powershell
docker compose --env-file .env -f compose/docker-compose.yml ps
```

正常な場合、以下のように`healthy`となる。

```text
NAME             STATUS
cicd-env-test    Up ... (healthy)
```

---

## 11. ログ確認

```powershell
docker compose --env-file .env -f compose/docker-compose.yml logs
```

リアルタイム確認：

```powershell
docker compose --env-file .env -f compose/docker-compose.yml logs -f
```

終了：

```text
Ctrl + C
```

---

## 12. Docker Volume確認

```powershell
docker volume ls
```

以下を確認する。

```text
cicd-env-test-data
```

詳細：

```powershell
docker volume inspect cicd-env-test-data
```

---

## 13. Docker Network確認

```powershell
docker network ls
```

以下を確認する。

```text
cicd-env-network
```

詳細：

```powershell
docker network inspect cicd-env-network
```

---

## 14. 停止

```powershell
docker compose --env-file .env -f compose/docker-compose.yml down
```

コンテナが停止・削除されることを確認する。

---

## 15. Volume保持確認

```powershell
docker volume ls
```

以下が残っていることを確認する。

```text
cicd-env-test-data
```

`docker compose down`では通常Volumeを削除しないため、Volumeは保持される。

---

## 16. Volumeを含めた完全削除

以下を実行するとVolumeも削除される。

```powershell
docker compose --env-file .env -f compose/docker-compose.yml down -v
```

> **注意**
>
> 本番運用では不用意に`down -v`を実行しない。
>
> 永続データが削除される可能性がある。

---

## 17. 正式なCompose操作コマンド

CICD-ENVでは以下の形式を標準とする。

### Config

```powershell
docker compose --env-file .env -f compose/docker-compose.yml config
```

### Start

```powershell
docker compose --env-file .env -f compose/docker-compose.yml up -d
```

### Status

```powershell
docker compose --env-file .env -f compose/docker-compose.yml ps
```

### Logs

```powershell
docker compose --env-file .env -f compose/docker-compose.yml logs
```

### Follow Logs

```powershell
docker compose --env-file .env -f compose/docker-compose.yml logs -f
```

### Stop

```powershell
docker compose --env-file .env -f compose/docker-compose.yml down
```

---

## 18. 完了条件

- [x] `.env`作成
- [x] `docker-compose.yml`作成
- [x] Compose構文確認
- [x] コンテナ起動
- [x] Healthcheck確認
- [x] Docker Volume確認
- [x] Docker Network確認
- [x] コンテナ停止確認

---

## 19. 動作確認済み事項

以下のコマンドによりCompose設定の読み込みに成功している。

```powershell
docker compose --env-file .env -f compose/docker-compose.yml config
```

`.env`を明示的に指定することで、環境変数が正常に読み込まれることを確認済み。

---
