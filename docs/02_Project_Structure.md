# プロジェクト構成構築手順書

## 1. 目的

本手順では、CICD-ENVプロジェクトの基本ディレクトリ構成を構築する。

Docker Compose、CI/CD、バックアップ、監視などを将来的に追加できる構成を作成する。

---

## 2. プロジェクト名

```text
CICD-ENV
```

ローカルプロジェクトディレクトリ：

```text
C:\workspace\CICD-env
```

GitHubリポジトリ名：

```text
CICD-ENV
```

---

## 3. ディレクトリ構成

```text
CICD-ENV/
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

## 4. Git初期化

プロジェクトディレクトリへ移動する。

```powershell
cd C:\workspace\CICD-env
```

Gitを初期化する。

```powershell
git init
```

確認：

```powershell
git status
```

---

## 5. `.gitignore`

以下を設定する。

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
Desktop.ini

# IDE
.idea/
.vscode/
```

---

## 6. `.env.example`

```dotenv
# Environment
TZ=Asia/Tokyo

# Game Server
GAME_SERVER_NAME=CICD-ENV
```

`.env.example` はGit管理対象とする。

---

## 7. `.env`

`.env.example`をコピーして`.env`を作成する。

```powershell
Copy-Item .env.example .env
```

`.env`はGit管理対象外とする。

---

## 8. README

READMEには以下を記載する。

```markdown
# CICD-ENV

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
```

---

## 9. Git初回コミット

```powershell
git add .
```

```powershell
git commit -m "chore: initialize project structure"
```

---

## 10. GitHubリポジトリ

GitHub上に以下のリポジトリを作成する。

```text
CICD-ENV
```

ゲームサーバーの設定等を含む可能性があるため、Private Repositoryを推奨する。

---

## 11. Remote設定

```powershell
git remote add origin <GitHubリポジトリURL>
```

確認：

```powershell
git remote -v
```

---

## 12. mainブランチ

```powershell
git branch -M main
```

---

## 13. Push

```powershell
git push -u origin main
```

---

## 14. 完了条件

- [x] CICD-ENVディレクトリ作成
- [x] Git初期化
- [x] ディレクトリ構成作成
- [x] `.gitignore`作成
- [x] `.env.example`作成
- [x] `.env`作成
- [x] README作成
- [x] GitHubリポジトリ作成
- [x] GitHubへPush

---
