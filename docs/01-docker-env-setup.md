# Docker開発環境構築手順書

## 1. 目的

本手順書では、Windows 11 Home上にDocker Desktopを利用した開発環境を構築する。

最終目標は以下の環境を構築することである。

- Docker Desktop
- WSL2
- Ubuntu 24.04 LTS
- Docker Compose V2
- Git
- GitHub ActionsによるCI/CD

---

## 2. 前提環境

| 項目 | 内容 |
|---|---|
| OS | Windows 11 Home |
| CPU | AMD Ryzen 7 5700U |
| メモリ | 16GB（利用可能 約10GB） |
| Docker Desktop | インストール済み |
| WSL2 | インストール済み |
| Ubuntu | Ubuntu 24.04 LTS |
| Docker Compose | Docker Compose V2 |
| 運用予定 | 最終的に24時間稼働 |

---

## 3. 構築フロー

```text
Windows 11
    │
    ├── WSL2
    │
    ├── Ubuntu 24.04
    │
    ├── Docker Desktop
    │
    └── Git
            │
            ▼
      Docker Compose
            │
            ▼
        CICD-ENV
            │
            ├── Satisfactory Server
            ├── Backup
            ├── Monitoring
            └── CI/CD
```

---

## 4. 仮想化の確認

### 手順

1. タスクマネージャーを起動する。

```text
Ctrl + Shift + Esc
```

2. 「パフォーマンス」を開く。

3. 「CPU」を選択する。

4. 「仮想化」が以下になっていることを確認する。

```text
有効
```

無効の場合はBIOSでAMD SVM等の仮想化機能を有効にする。

---

## 5. WSL2のインストール

PowerShellを管理者権限で起動する。

```powershell
wsl --install
```

インストール完了後、PCを再起動する。

---

## 6. WSL2の状態確認

```powershell
wsl --status
```

WSLの既定バージョンが2になっていることを確認する。

```text
Default Version: 2
```

---

## 7. Ubuntu 24.04のインストール

Ubuntuがインストールされていない場合は以下を実行する。

```powershell
wsl --install -d Ubuntu-24.04
```

初回起動時にUbuntuユーザーを作成する。

```text
Enter new UNIX username:
```

続いてパスワードを設定する。

```text
New password:
```

---

## 8. Ubuntu更新

Ubuntuを起動し、以下を実行する。

```bash
sudo apt update
sudo apt upgrade -y
```

---

## 9. Docker Desktop

Docker Desktopをインストールする。

WSL2ベースのDocker Engineを使用する。

Docker Desktopの設定から、

```text
Settings
  ↓
Resources
  ↓
WSL Integration
```

を開き、Ubuntu 24.04のWSL Integrationを有効にする。

---

## 10. Docker動作確認

Dockerのバージョンを確認する。

```powershell
docker --version
```

Docker Composeのバージョンを確認する。

```powershell
docker compose version
```

Hello Worldを実行する。

```powershell
docker run hello-world
```

以下のメッセージが表示されればDockerは正常に動作している。

```text
Hello from Docker!
This message shows that your installation appears to be working correctly.
```

---

## 11. Docker環境の完了条件

- [x] WSL2がVersion 2で動作
- [x] Ubuntu 24.04が起動
- [x] Docker Desktopが起動
- [x] Dockerが利用可能
- [x] Docker Compose V2が利用可能
- [x] `docker run hello-world` が成功

---
