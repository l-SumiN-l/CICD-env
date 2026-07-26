# Satisfactory Dedicated Server Infrastructure

## 概要

本リポジトリは、**Satisfactory Dedicated Server** を Docker 上で運用するためのインフラ構成を管理します。

本プロジェクトでは、以下の方針を重視します。

- Docker による再現性のある環境構築
- GitHub による Infrastructure as Code (IaC)
- GitHub Actions を利用した CI
- 安全なデプロイ
- 定期バックアップ
- 半年以上の安定運用
- 原則無料サービスのみ利用

---

# 開発方針

本プロジェクトは以下の思想で運用します。

## 再現性

誰が環境を構築しても同じサーバーが構築できること。

環境構築は手作業ではなく Docker Compose により自動化します。

---

## 安定性

便利さよりも安全性を優先します。

CI によって品質を保証し、問題のある設定は本番環境へ反映しません。

---

## 保守性

設定・スクリプト・バックアップ方法・運用手順をすべて GitHub 上で管理します。

属人化しないことを目標とします。

---

# システム構成

```
Windows11 Home
│
├─ WSL2
│
├─ Docker Desktop
│
├─ Docker Compose
│
├─ Satisfactory Dedicated Server
│
├─ Backup Script
│
└─ Git
```

---

# 利用予定ツール

|用途|ツール|ライセンス|
|------|------|-----------|
|ソース管理|GitHub|Free|
|CI|GitHub Actions|Free|
|コンテナ|Docker Desktop|Personal|
|コンテナ管理|Docker Compose|Free|
|エディタ|Visual Studio Code|Free|
|スクリプト|PowerShell 7|Free|
|バックアップ|PowerShell|Free|

---

# CI方針

CIではデプロイは行いません。

目的は品質保証です。

```
Push

↓

GitHub Actions

↓

YAMLチェック

↓

Docker Compose構文チェック

↓

Docker Build

↓

コンテナ起動テスト

↓

PowerShell Lint

↓

Secret Scan

↓

成功

↓

Merge可能
```

---

## CIで実施する項目

- YAML構文チェック
- Docker Compose構文チェック
- Docker Build
- コンテナ起動確認
- Health Check
- PowerShell Script Lint
- Secret Scan
- Backup Script Test（予定）
- Restore Test（予定）

---

## CIで実施しない項目

以下はCI対象外とします。

- ワールド生成
- Steam接続確認
- 長時間動作確認
- パフォーマンステスト

---

# ブランチ戦略

```
main
 ↑
 │ Pull Request
 │
develop
 ↑
 │
feature/*
```

## main

本番環境

---

## develop

動作確認環境

---

## feature

機能開発

---

# デプロイ方針

本番サーバーへのデプロイは GitHub Actions から直接行いません。

Windows側が定期的に GitHub を監視します。

```
Task Scheduler

↓

git pull

↓

docker compose pull

↓

docker compose up -d
```

これにより Windows Home 環境でも安全に運用できます。

---

# バックアップ方針

バックアップは自動取得します。

対象

- セーブデータ
- サーバー設定
- Docker Compose設定

取得タイミング

- 定期実行
- 更新前
- 手動実行

バックアップは世代管理します。

---

# ディレクトリ構成（予定）

```
.
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
├── docs/
│
├── logs/
│
└── README.md
```

---

# 今後追加予定

- Docker Compose詳細設計
- バックアップ設計
- Restore手順
- GitHub Actions
- 障害対応手順
- 更新手順
- 監視機能
- Discord通知
- ログ管理

---

# 運用目標

|項目|目標|
|------|------|
|稼働率|半年以上継続運用|
|バックアップ|自動取得|
|復旧|バックアップから復元可能|
|更新|GitHub管理|
|構築時間|新規構築30分以内|
|運用コスト|無料|

---

# ライセンス

本プロジェクトは個人利用を目的として管理します。