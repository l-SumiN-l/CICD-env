# Task Scheduler Deploy

## 1. 目的

本番サーバー（Windows 11 Home）へのデプロイは、GitHub Actionsから直接行わない。Windowsのタスクスケジューラが定期的に次の処理を実行する。

```text
git pull → docker compose config → (docker compose pull) → docker compose up -d
```

このドキュメントは、その設定方法をまとめたものである。`main`ブランチの内容を本番へ反映する運用を前提とする。

## 2. 前提と確認済みの事項

| 項目 | 内容 |
|---|---|
| OS | Windows 11 Home（タスクスケジューラは標準で使用可能） |
| Docker Desktop | スタートアップアプリに追加済み。ログイン時に自動起動する |
| PowerShell | 標準の`powershell.exe`（5.1）は使用可能。`pwsh`（PowerShell 7）は未インストール（2026-10-18確認） |
| Docker Desktop再起動後 | コンテナは自動復旧しない（2026-10-18確認）。`restart: unless-stopped`でも、Docker Desktopを終了すると停止したままになった |
| 結論 | Docker Desktopの再起動後は、タスクスケジューラの`docker compose up -d`で復旧させる |

## 3. 設計上の注意

### 3.1 タスクは「ユーザーがログオンしているときのみ実行」にする

Docker Desktopはユーザーのログオン中に動作する。そのため、タスクは「ユーザーがログオンしているときのみ実行する」設定にする。パスワードの保存は不要である。サービスとして常駐させる構成ではない。

### 3.2 `docker compose pull`と更新の衝突

このイメージは、コンテナの起動時にゲーム本体を自動更新する（`docs/04_Satisfactory_Server.md`の「更新運用の注意」を参照）。`docker compose pull`で新しいイメージを取得して`up -d`すると、コンテナが再作成され、プレイ中のサーバーが再起動する。

本プロジェクトの方針は「更新前にバックアップを取り、失敗したら更新しない」である。バックアップ手順（`docs/05_Backup.md`）が未整備の間は、次のとおりにする。

- スクリプトの`$PullImage`を`$false`にして、`docker compose pull`を実行しない
- イメージのバージョンは、`.env`の`SATISFACTORY_IMAGE_TAG`で管理する
- バックアップ手順の整備後に、`$PullImage`を`$true`にすることを検討する

### 3.3 実行時刻

`up -d`は、設定とイメージに変更がなければ何もしない。ただし、設定やイメージが変わっていると、サーバーが再起動する。実行時刻は、プレイしない時間帯（例: 午前4時）にする。

### 3.4 実行するブランチ

本番のワーキングツリーは、`main`ブランチにしておく。スクリプトは、`main`以外のブランチや、未コミットの変更がある場合は中止する。

## 4. デプロイスクリプト（サンプル）

> 現時点ではサンプルであり、リポジトリには配置していない。動作確認は未実施。配置する場合は`scripts/deploy/deploy.ps1`とする。

```powershell
# CICD-ENV deploy script (Windows PowerShell 5.1 compatible)
$repo      = 'C:\workspace\CICD-env'
$logFile   = Join-Path $repo 'logs\deploy.log'
$PullImage = $false   # バックアップ手順の整備前は $false のままにする

function Write-Log([string]$Message) {
    $line = '{0} {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -Path $logFile -Value $line -Encoding utf8
}

function Invoke-Native([string]$Name, [scriptblock]$Command) {
    & $Command *> $null
    if ($LASTEXITCODE -ne 0) {
        Write-Log "失敗: $Name (終了コード $LASTEXITCODE)"
        exit 1
    }
    Write-Log "成功: $Name"
}

Set-Location $repo
New-Item -ItemType Directory -Force (Split-Path $logFile) | Out-Null
Write-Log '--- デプロイ開始 ---'

# Docker Desktopの起動を最大5分待つ（ログオン直後の実行に備える）
$ready = $false
for ($i = 0; $i -lt 30; $i++) {
    docker info *> $null
    if ($LASTEXITCODE -eq 0) { $ready = $true; break }
    Start-Sleep -Seconds 10
}
if (-not $ready) { Write-Log 'Dockerが起動していないため中止'; exit 1 }

$branch = git branch --show-current
if ($branch -ne 'main') { Write-Log "mainではない($branch)ため中止"; exit 1 }
if (git status --porcelain) { Write-Log '未コミットの変更があるため中止'; exit 1 }

$c = @('--env-file', '.env', '-f', 'compose/docker-compose.yml')

Invoke-Native 'git pull' { git pull --ff-only }
Invoke-Native 'docker compose config' { docker compose @c config -q }
if ($PullImage) { Invoke-Native 'docker compose pull' { docker compose @c pull } }
Invoke-Native 'docker compose up -d' { docker compose @c up -d }

Write-Log '--- デプロイ終了 ---'
```

- `down -v`は含まない。`data/`にも触れない
- `logs/deploy.log`に結果を記録する（`logs/`はGit管理対象外）
- `git pull`は`--ff-only`にして、意図しないマージを防ぐ

## 5. タスクの登録

### 5.1 PowerShellで登録する

通常のPowerShell（管理者権限は不要）で実行する。

```powershell
$script  = 'C:\workspace\CICD-env\scripts\deploy\deploy.ps1'
$action  = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$script`"" `
    -WorkingDirectory 'C:\workspace\CICD-env'

$logon       = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$logon.Delay = 'PT3M'
$daily       = New-ScheduledTaskTrigger -Daily -At 4:00

$settings  = New-ScheduledTaskSettingsSet -StartWhenAvailable `
    -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Hours 1)
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME `
    -LogonType Interactive -RunLevel Limited

Register-ScheduledTask -TaskName 'CICD-ENV Deploy' `
    -Action $action -Trigger @($logon, $daily) `
    -Settings $settings -Principal $principal
```

| 設定 | 値 | 理由 |
|---|---|---|
| トリガー1 | ログオン時（3分遅延） | Docker Desktopの再起動後に、コンテナを復旧させる |
| トリガー2 | 毎日4:00 | `main`の変更を定期的に反映する |
| `StartWhenAvailable` | 有効 | PCがスリープや停止中で実行時刻を逃した場合、復帰後に実行する |
| `MultipleInstances` | `IgnoreNew` | 実行中に重複して起動しない |
| `ExecutionTimeLimit` | 1時間 | 処理が止まった場合に打ち切る |
| `LogonType` | `Interactive` | ユーザーがログオンしているときのみ実行する（3.1を参照） |
| `RunLevel` | `Limited` | 管理者権限は使わない |

### 5.2 GUIで登録する場合

1. スタートメニューで「タスク スケジューラ」を開く
2. 右側の「タスクの作成」を選ぶ（「基本タスクの作成」ではない）
3. 「全般」タブで、名前を`CICD-ENV Deploy`にし、「ユーザーがログオンしているときのみ実行する」を選ぶ
4. 「トリガー」タブで、「ログオン時」（遅延3分）と「毎日」（4:00）を追加する
5. 「操作」タブで、プログラムに`powershell.exe`、引数に`-NoProfile -ExecutionPolicy Bypass -File "C:\workspace\CICD-env\scripts\deploy\deploy.ps1"`、開始に`C:\workspace\CICD-env`を指定する
6. 「設定」タブで、「予定された時刻にタスクを開始できなかった場合、すぐにタスクを開始する」にチェックし、「タスクが既に実行中の場合」を「新しいインスタンスを開始しない」にする

## 6. 動作確認

```powershell
Start-ScheduledTask -TaskName 'CICD-ENV Deploy'
Get-ScheduledTaskInfo -TaskName 'CICD-ENV Deploy' | Select-Object LastRunTime, LastTaskResult
Get-Content C:\workspace\CICD-env\logs\deploy.log -Tail 20
docker compose --env-file .env -f compose/docker-compose.yml ps
```

| 確認項目 | 期待する結果 |
|---|---|
| `LastTaskResult` | `0` |
| `deploy.log` | 各手順が「成功」で、最後に「デプロイ終了」が出る |
| コンテナ | 起動していて`healthy`である |

### 復旧の確認

1. サーバーが起動している状態で、Docker Desktopを終了する
2. Docker Desktopを起動し直す（またはWindowsから再ログオンする）
3. ログオンから約3分後にタスクが実行され、コンテナが自動で`healthy`に戻ることを確認する

## 7. 無効化と削除

```powershell
Disable-ScheduledTask    -TaskName 'CICD-ENV Deploy'
Enable-ScheduledTask     -TaskName 'CICD-ENV Deploy'
Unregister-ScheduledTask -TaskName 'CICD-ENV Deploy' -Confirm:$false
```

サーバーのメンテナンス中や、設定を検証中のブランチへ切り替えているときは、先に`Disable-ScheduledTask`で無効化する。

## 8. トラブルシューティング

| 症状 | 原因と対処 |
|---|---|
| `LastTaskResult`が`1` | `logs/deploy.log`の最後の行を確認する |
| 「Dockerが起動していないため中止」 | Docker Desktopがスタートアップに入っているか確認する。起動に5分以上かかる場合は、待ち時間を延ばす |
| 「mainではない」で中止 | 本番のワーキングツリーを`main`に戻す |
| 「未コミットの変更がある」で中止 | 本番側の変更を確認し、コミットまたは破棄する。破棄は内容を確認してから行う |
| タスクが実行されない | 「ユーザーがログオンしているときのみ実行する」のため、ログオンしていないと実行されない |
| `git pull`が失敗する | 認証が必要か確認する（Git Credential Managerの認証は対話が必要になる場合がある） |

## 9. 未確認事項

- デプロイスクリプトとタスクの動作確認（サンプルの段階）
- タスクの`git pull`で、Git Credential Managerの認証が非対話で通るか
- PCのスリープ中の扱い（スリープするとサーバーも停止する）
