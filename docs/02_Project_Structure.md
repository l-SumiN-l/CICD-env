# プロジェクト構成構築手順書

## 1. 目的

本手順では、Dockerを利用したゲームサーバー環境のプロジェクト基盤を構築する。

今回の段階ではゲームサーバー本体は構築せず、以下を整備する。

- Gitリポジトリ
- ディレクトリ構成
- Docker Compose用ディレクトリ
- スクリプト用ディレクトリ
- 設定ファイル用ディレクトリ
- データ保存用ディレクトリ
- ログ用ディレクトリ
- ドキュメント構成
- `.gitignore`
- `.env.example`

---

# 2. 想定する最終構成

```text
GameServer/
├── .github/
│   └── workflows/
│
├── compose/
│
├── scripts/
│   ├── backup/
│   ├── restore/
│   ├── deploy/
│   └── maintenance/
│
├── config/
│
├── data/
│
├── logs/
│
├── docs/
│   ├── 01_Docker_Environment_Setup.md
│   ├── 02_Project_Structure.md
│   ├── 03_Docker_Compose.md
│   ├── 04_GitHub_Actions.md
│   ├── 05_Backup.md
│   ├── 06_Monitoring.md
│   └── Architecture.md
│
├── .env.example
├── .gitignore
├── README.md
└── LICENSE
```

---

# 3. プロジェクトディレクトリ作成

Windows側でプロジェクトを作成する。

例：

```powershell
mkdir GameServer
cd GameServer
```

---

# 4. Gitリポジトリ初期化

```powershell
git init
```

確認：

```powershell
git status
```

---

# 5. ディレクトリ作成

PowerShellで以下を実行する。

```powershell
mkdir .github
mkdir .github\workflows

mkdir compose

mkdir scripts
mkdir scripts\backup
mkdir scripts\restore
mkdir scripts\deploy
mkdir scripts\maintenance

mkdir config
mkdir data
mkdir logs

mkdir docs
```

---

# 6. ドキュメント用ファイル作成

```powershell
New-Item docs\01_Docker_Environment_Setup.md
New-Item docs\02_Project_Structure.md
New-Item docs\03_Docker_Compose.md
New-Item docs\04_GitHub_Actions.md
New-Item docs\05_Backup.md
New-Item docs\06_Monitoring.md
New-Item docs\Architecture.md
```

---

# 7. .gitignore作成

プロジェクトルートに `.gitignore` を作成する。

```powershell
New-Item .gitignore
```

以下を記述する。

```gitignore
# Environment
.env

# Docker
*.pid

# Logs
logs/
*.log

# Game server data
data/

# Backup
backup/
backups/

# Temporary files
*.tmp
*.temp

# OS
.DS_Store
Thumbs.db

# IDE
.idea/
.vscode/

# Windows
Desktop.ini
```

> `data/` はゲームサーバーのセーブデータなどを保存するため、Git管理対象外とする。

---

# 8. .env.example作成

```powershell
New-Item .env.example
```

初期状態では以下を記述する。

```dotenv
# Environment
TZ=Asia/Tokyo

# Game Server
GAME_SERVER_NAME=GameServer

# Docker
COMPOSE_PROJECT_NAME=gameserver
```

`.env.example` はGit管理対象とする。

実際の環境設定を行う場合は、

```text
.env.example
    ↓ コピー
.env
```

として使用する。

`.env` はGit管理対象外とする。

---

# 9. README.md作成

プロジェクトルートに `README.md` を作成する。

```markdown
# Game Server Infrastructure

Dockerを利用したゲームサーバー運用基盤。

## Environment

- Windows 11 Home
- WSL2
- Ubuntu 24.04 LTS
- Docker Desktop
- Docker Compose V2
- GitHub Actions

## Goals

- Dockerによるゲームサーバー運用
- 24時間安定稼働
- 自動バックアップ
- CI/CD
- ログ管理
- 監視
- 自動デプロイ

## Directory Structure

```text
GameServer/
├── .github/
├── compose/
├── scripts/
├── config/
├── data/
├── logs/
├── docs/
├── .env.example
├── .gitignore
└── README.md
```

## Documentation

- [Docker環境構築](docs/01_Docker_Environment_Setup.md)
- [プロジェクト構成](docs/02_Project_Structure.md)
- [Docker Compose](docs/03_Docker_Compose.md)
- [GitHub Actions](docs/04_GitHub_Actions.md)
- [バックアップ](docs/05_Backup.md)
- [監視](docs/06_Monitoring.md)
- [Architecture](docs/Architecture.md)
```

---

# 10. 空ディレクトリについて

Gitは空のディレクトリを管理しない。

そのため、以下のディレクトリには `.gitkeep` を配置する。

```text
compose/
scripts/backup/
scripts/restore/
scripts/deploy/
scripts/maintenance/
config/
data/
logs/
.github/workflows/
```

PowerShell：

```powershell
New-Item compose\.gitkeep
New-Item scripts\backup\.gitkeep
New-Item scripts\restore\.gitkeep
New-Item scripts\deploy\.gitkeep
New-Item scripts\maintenance\.gitkeep
New-Item config\.gitkeep
New-Item data\.gitkeep
New-Item logs\.gitkeep
New-Item .github\workflows\.gitkeep
```

---

# 11. 構成確認

以下を実行する。

```powershell
tree /F
```

以下のような構成になっていればよい。

```text
GameServer
│  .env.example
│  .gitignore
│  README.md
│
├─.github
│  └─workflows
│      .gitkeep
│
├─compose
│      .gitkeep
│
├─config
│      .gitkeep
│
├─data
│      .gitkeep
│
├─docs
│      01_Docker_Environment_Setup.md
│      02_Project_Structure.md
│      03_Docker_Compose.md
│      04_GitHub_Actions.md
│      05_Backup.md
│      06_Monitoring.md
│      Architecture.md
│
├─logs
│      .gitkeep
│
└─scripts
    ├─backup
    │      .gitkeep
    ├─deploy
    │      .gitkeep
    ├─maintenance
    │      .gitkeep
    └─restore
           .gitkeep
```

---

# 12. Gitの初回コミット

構成を確認したら、

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
git commit -m "chore: initialize project structure"
```

---

# 13. GitHubリポジトリ作成

GitHub上で新しいリポジトリを作成する。

推奨設定：

```text
Repository name:
GameServer

Visibility:
Private
```

ゲームサーバーの設定や運用情報を含む可能性があるため、最初はPrivateを推奨する。

GitHub側ではREADMEや.gitignoreを自動生成せず、ローカルで作成したものをPushする。

---

# 14. GitHubリモート設定

GitHubリポジトリ作成後、リモートを登録する。

```powershell
git remote add origin <GitHubリポジトリURL>
```

確認：

```powershell
git remote -v
```

---

# 15. mainブランチ設定

```powershell
git branch -M main
```

---

# 16. GitHubへPush

```powershell
git push -u origin main
```

GitHub上で以下が確認できれば完了。

- README.md
- docs/
- compose/
- scripts/
- config/
- .github/
- .gitignore
- .env.example

---

# 17. 完了条件

以下を満たしていれば本手順は完了。

- [ ] Gitリポジトリが作成されている
- [ ] ディレクトリ構成が作成されている
- [ ] `.gitignore` が作成されている
- [ ] `.env.example` が作成されている
- [ ] README.mdが作成されている
- [ ] 初回コミットが完了している
- [ ] GitHubリポジトリが作成されている
- [ ] GitHubへPushできている

---
