# Docker Compose基盤構築手順書

## 1. 目的

本手順では、CICD-ENVプロジェクトにDocker Composeの基盤を構築する。

今回の目的は以下のとおり。

- Docker Compose V2を利用する
- `.env` による環境設定を導入する
- Dockerネットワークを定義する
- Docker Volumeを定義する
- コンテナのヘルスチェックを確認する
- Docker Composeによる起動・停止を確認する

この段階ではSatisfactory Serverはまだ導入しない。

---

# 2. 前提環境

| 項目 | 内容 |
|---|---|
| OS | Windows 11 Home |
| WSL | WSL2 |
| Linux | Ubuntu 24.04 LTS |
| Docker | Docker Desktop |
| Compose | Docker Compose V2 |
| プロジェクト | CICD-ENV |

---

# 3. 今回の構成

```text
CICD-ENV/
│
├── compose/
│   └── docker-compose.yml
│
├── config/
│
├── data/
│
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

# 4. `.env` の作成

プロジェクトルートで以下を実行する。

```powershell
Copy-Item .env.example .env
```

作成された `.env` を確認する。

```powershell
Get-Content .env
```

初期状態：

```dotenv
# Environment
TZ=Asia/Tokyo

# Project
COMPOSE_PROJECT_NAME=cicd-env

# Game Server
GAME_SERVER_NAME=CICD-ENV
```

---

# 5. Docker Composeファイル作成

`compose/docker-compose.yml` を作成する。

```yaml
name: ${COMPOSE_PROJECT_NAME}

services:

  test:
    image: nginx:alpine

    container_name: ${COMPOSE_PROJECT_NAME}-test

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
    name: ${COMPOSE_PROJECT_NAME}-network
    driver: bridge


volumes:

  test-data:
    name: ${COMPOSE_PROJECT_NAME}-test-data
```

---

# 6. Composeファイルの説明

## 6.1 name

```yaml
name: ${COMPOSE_PROJECT_NAME}
```

`.env` に設定したプロジェクト名を使用する。

```dotenv
COMPOSE_PROJECT_NAME=cicd-env
```

そのため、Docker Compose上では

```text
cicd-env
```

というプロジェクトとして管理される。

---

# 7. Service

今回のテスト用サービスは、

```yaml
services:
  test:
```

としている。

使用するイメージ：

```yaml
image: nginx:alpine
```

これはDocker Composeの基盤確認専用であり、Satisfactory Serverではない。

---

# 8. Container Name

```yaml
container_name: ${COMPOSE_PROJECT_NAME}-test
```

`.env` が

```dotenv
COMPOSE_PROJECT_NAME=cicd-env
```

の場合、

```text
cicd-env-test
```

というコンテナ名になる。

---

# 9. Restart Policy

```yaml
restart: "no"
```

今回は動作確認用コンテナなので自動再起動を無効にする。

Satisfactory Serverを導入する段階では、運用要件を考慮して適切なrestart policyを設定する。

---

# 10. Environment

```yaml
environment:
  TZ: ${TZ}
```

`.env` の

```dotenv
TZ=Asia/Tokyo
```

をコンテナへ渡す。

これにより、ログなどの時刻を日本時間に統一しやすくする。

---

# 11. Volume

```yaml
volumes:
  - test-data:/usr/share/nginx/html
```

Docker Volumeを使用してコンテナ外にデータを保持する。

Volumeの定義：

```yaml
volumes:
  test-data:
```

今回のVolumeはCompose基盤確認用である。

Satisfactory Serverでは、セーブデータなどの永続データについて別途設計する。

---

# 12. Network

```yaml
networks:

  cicd-env-network:
    name: ${COMPOSE_PROJECT_NAME}-network
    driver: bridge
```

コンテナ間通信に使用するDockerネットワークを定義する。

最終的には、

```text
cicd-env-network
│
├── satisfactory
├── backup
├── monitoring
└── その他サービス
```

という構成を想定する。

---

# 13. Healthcheck

```yaml
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
```

コンテナ内部のNginxへHTTPアクセスできるか確認する。

状態は以下のように確認できる。

```powershell
docker compose ps
```

正常であれば、

```text
healthy
```

と表示される。

---

# 14. Composeファイルの検証

プロジェクトルートから実行する。

```powershell
docker compose -f compose/docker-compose.yml config
```

エラーがなければComposeファイルの構文は正常。

---

# 15. コンテナ起動

```powershell
docker compose -f compose/docker-compose.yml up -d
```

状態確認：

```powershell
docker compose -f compose/docker-compose.yml ps
```

正常な状態の例：

```text
NAME              STATUS
cicd-env-test     Up ... (healthy)
```

---

# 16. コンテナログ確認

```powershell
docker compose -f compose/docker-compose.yml logs
```

リアルタイムで確認する場合：

```powershell
docker compose -f compose/docker-compose.yml logs -f
```

終了する場合：

```text
Ctrl + C
```

---

# 17. コンテナへのアクセス確認

ブラウザから以下へアクセスする。

```text
http://localhost
```

ただし、今回のComposeではポート公開を設定していないため、ブラウザからのアクセスはできない。

これは意図した状態である。

今回確認するのは、

```text
Docker
 ↓
Compose
 ↓
Container
 ↓
Healthcheck
```

の動作である。

---

# 18. Volume確認

以下を実行する。

```powershell
docker volume ls
```

以下のVolumeが存在することを確認する。

```text
cicd-env-test-data
```

詳細確認：

```powershell
docker volume inspect cicd-env-test-data
```

---

# 19. Network確認

以下を実行する。

```powershell
docker network ls
```

以下のネットワークが存在することを確認する。

```text
cicd-env-network
```

詳細確認：

```powershell
docker network inspect cicd-env-network
```

---

# 20. 停止

Composeを停止する。

```powershell
docker compose -f compose/docker-compose.yml down
```

状態確認：

```powershell
docker compose -f compose/docker-compose.yml ps
```

コンテナが停止・削除されていることを確認する。

---

# 21. Volumeが残っていることを確認

再度、

```powershell
docker volume ls
```

を実行する。

```text
cicd-env-test-data
```

が残っていることを確認する。

これは重要なポイントである。

```text
docker compose down
        │
        ├── Container → 削除
        │
        ├── Network   → 削除
        │
        └── Volume    → 原則保持
```

そのため、コンテナを削除しても永続データを保持できる。

---

# 22. 完全削除について

Volumeまで削除する場合は、

```powershell
docker compose -f compose/docker-compose.yml down -v
```

を使用する。

> 本番運用では `down -v` を不用意に実行しないこと。
>
> Volume内の永続データが削除される可能性がある。

---

# 23. 完了条件

以下を確認する。

- [ ] `.env` を作成した
- [ ] `docker-compose.yml` を作成した
- [ ] `docker compose config` が成功した
- [ ] コンテナを起動できた
- [ ] `healthy` を確認できた
- [ ] Docker Volumeを確認できた
- [ ] Docker Networkを確認できた
- [ ] `docker compose down` が成功した
- [ ] Volumeが保持されることを確認した

---

# 24. Gitへの反映

作業完了後、

```powershell
git status
```

で変更内容を確認する。

問題がなければ、

```powershell
git add .
```

続いて、

```powershell
git commit -m "feat: add docker compose foundation"
```

---

# 25. 注意事項

## `.env` はGitへPushしない

`.gitignore` に以下が含まれていることを確認する。

```gitignore
.env
```

確認：

```powershell
git check-ignore .env
```

`.env` が表示されればGit管理対象外になっている。

---
