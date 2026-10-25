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
| Docker Desktopだけを終了して起動し直した場合 | コンテナは自動復旧しない（2026-10-18確認）。`restart: unless-stopped`でも、Docker Desktopを終了すると停止したままになった |
| PCを再起動した場合 | コンテナは自動復旧した（2026-10-18確認。PCの起動の約1分後にコンテナが起動した） |
| 結論 | PCの再起動は自動で復旧する。Docker Desktopだけを再起動した場合や、予期しない停止に備えて、タスクスケジューラの`docker compose up -d`でも復旧させる |

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

> 実際のスクリプトは`scripts/deploy/deploy.ps1`に配置した（構文の確認のみ。実行とタスクの登録は未実施）。次のサンプルとの違いは、リポジトリのパスを自身の位置から求めること、バックアップの呼び出し口（`scripts/backup/backup.ps1`。未配置の間は警告して続行する）、更新後に`healthy`になるまで最大5分待つことである。BOM付きUTF-8で保存すること（BOMがないとPowerShell 5.1が日本語を文字化けさせる）。
> 管理用APIの`SaveGame`による停止前セーブは、認証情報の扱いが未決のため、まだ組み込んでいない（`docs/05_Backup.md`の11のNo.5）。

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

タスクを登録する前は、手順2の後もコンテナは自動で復旧しない。タスクの登録後に、この確認を行う。

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

## 9. 監視タスク（CICD-ENV Monitor）

コンテナの状態を5分ごとに確認し、Discordへ通知する（`docs/06_Monitoring.md`）。デプロイのタスクとは別のタスクにする。

| 通知 | タイミング |
|---|---|
| 定期通知 | 1時間に1回（毎時0分ごろ）。正常でも異常でも、現在の状態を送る |
| 異常の通知 | 異常が連続3回（約15分）続いたとき、1回だけ |
| 復旧の通知 | 異常から`healthy`に戻ったとき、1回だけ |

### 9.1 事前の確認

- `.env`の`DISCORD_WEBHOOK_URL`が設定済みである（値を画面に出さずに確認する）

```powershell
Select-String -Path C:\workspace\CICD-env\.env -Pattern '^DISCORD_WEBHOOK_URL=.+' -Quiet
```

`True`なら設定済み。

### 9.2 PowerShellで登録する

通常のPowerShell（管理者権限は不要）で実行する。

```powershell
$script = 'C:\workspace\CICD-env\scripts\maintenance\monitor.ps1'
$action = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`"" `
    -WorkingDirectory 'C:\workspace\CICD-env'

$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) `
    -RepetitionInterval (New-TimeSpan -Minutes 5) `
    -RepetitionDuration (New-TimeSpan -Days 3650)

$settings  = New-ScheduledTaskSettingsSet -StartWhenAvailable `
    -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 5)
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME `
    -LogonType Interactive -RunLevel Limited

Register-ScheduledTask -TaskName 'CICD-ENV Monitor' `
    -Action $action -Trigger $trigger `
    -Settings $settings -Principal $principal
```

| 設定 | 値 | 理由 |
|---|---|---|
| トリガー | 登録の1分後に開始し、5分ごとに繰り返す（期間は約10年） | 異常を連続3回（約15分）で検知するため |
| `-WindowStyle Hidden` | 有効 | 5分ごとにウィンドウが表示されるのを抑える（起動の一瞬は見える場合がある） |
| `StartWhenAvailable` | 有効 | スリープなどで実行時刻を逃した場合、復帰後に実行する |
| `MultipleInstances` | `IgnoreNew` | 実行中に重複して起動しない |
| `ExecutionTimeLimit` | 5分 | 処理が止まった場合に打ち切る |
| `LogonType` | `Interactive` | ユーザーがログオンしているときのみ実行する（3.1を参照）。Docker Desktopもログオン中のみ動作する |

### 9.3 GUIで登録する場合

1. 「タスクの作成」を選び、名前を`CICD-ENV Monitor`、「ユーザーがログオンしているときのみ実行する」を選ぶ
2. 「トリガー」で「新規」→ 「1回」、開始を今から1分後にし、「繰り返し間隔」を5分、「継続時間」を「無制限」にする
3. 「操作」で、プログラムに`powershell.exe`、引数に`-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\workspace\CICD-env\scripts\maintenance\monitor.ps1"`、開始に`C:\workspace\CICD-env`を指定する
4. 「設定」で、「予定された時刻にタスクを開始できなかった場合、すぐにタスクを開始する」にチェックし、「タスクが既に実行中の場合」を「新しいインスタンスを開始しない」にする

### 9.4 動作確認

```powershell
Start-ScheduledTask -TaskName 'CICD-ENV Monitor'
Start-Sleep -Seconds 10
Get-ScheduledTaskInfo -TaskName 'CICD-ENV Monitor' | Select-Object LastRunTime, LastTaskResult, NextRunTime
Get-Content C:\workspace\CICD-env\logs\monitor.log -Tail 10 -Encoding utf8
Get-Content C:\workspace\CICD-env\logs\monitor-state.json
```

| 確認項目 | 期待する結果 |
|---|---|
| `LastTaskResult` | `0` |
| `NextRunTime` | 約5分後 |
| `monitor-state.json` | `state`が`up`で、`lastReport`が現在の時刻（`yyyy-MM-dd HH`）になっている |
| Discord | 登録後の最初の実行で、`[定期]`の通知が1件届く。その後は毎時1件 |

### 9.5 一時的な無効化

登録は残したまま、実行だけ止める。サーバーを意図して止めるメンテナンスの前に行う（異常と定期通知が届き続けるのを防ぐ）。

```powershell
Disable-ScheduledTask -TaskName 'CICD-ENV Monitor'
Enable-ScheduledTask  -TaskName 'CICD-ENV Monitor'
```

1行目で無効化し、2行目で有効に戻す。無効化の間は、確認も通知も行われない。有効に戻すと、次の5分ごとの実行から再開する。

### 9.6 登録の解除（削除）

監視が不要になった場合や、登録をやり直す場合に行う。通常のPowerShell（管理者権限は不要）で実行する。

1. 登録されていることを確認する

```powershell
Get-ScheduledTask -TaskName 'CICD-ENV Monitor' | Select-Object TaskName, State
```

2. 実行中なら止める（実行中でなければ不要）

```powershell
Stop-ScheduledTask -TaskName 'CICD-ENV Monitor'
```

3. 登録を解除する

```powershell
Unregister-ScheduledTask -TaskName 'CICD-ENV Monitor' -Confirm:$false
```

4. 解除されたことを確認する

```powershell
Get-ScheduledTask -TaskName 'CICD-ENV Monitor' -ErrorAction SilentlyContinue
```

何も表示されなければ解除済み。

GUIで解除する場合は、「タスク スケジューラ」の「タスク スケジューラ ライブラリ」で`CICD-ENV Monitor`を右クリックし、「削除」を選ぶ。

解除の影響と残るもの:

| 項目 | 内容 |
|---|---|
| 解除で止まるもの | 5分ごとの確認、異常・復旧の通知、毎時の定期通知 |
| 影響しないもの | サーバー（コンテナ）、`CICD-ENV Deploy`タスク、`deploy.ps1`の失敗通知（デプロイの失敗はDiscordへ通知され続ける） |
| 残るもの | `.env`の`DISCORD_WEBHOOK_URL`、`logs/monitor.log`、`logs/monitor-state.json`、スクリプト一式。いずれも削除されない |

- 再び登録するときは、9.2の手順をそのまま実行する。`monitor-state.json`が残っていると、前回の状態から再開する（`down`のまま解除した場合は、復旧時に復旧の通知が1回届く）。初期状態から始めたい場合は、先に`logs\monitor-state.json`を削除する
- 通知を完全にやめる場合は、DiscordのチャンネルでWebhook自体も削除し、`.env`の`DISCORD_WEBHOOK_URL`を空にする（`deploy.ps1`の失敗通知も止まる）

## 10. 未確認事項

- デプロイスクリプトとタスクの動作確認（サンプルの段階）
- タスクの`git pull`で、Git Credential Managerの認証が非対話で通るか
- PCのスリープ中の扱い（スリープするとサーバーも停止する）
