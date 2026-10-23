# CICD-ENV deploy script (Windows PowerShell 5.1 compatible)
# main の内容を本番へ反映し、サーバーを起動した状態に保つ。docs/07_Task_Scheduler.md を参照。
# 失敗したら Discord へ通知する (docs/06_Monitoring.md)。
# このファイルは UTF-8 (BOM 付き) で保存すること。BOM がないと PowerShell 5.1 は日本語を文字化けさせる。

$repo          = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$logFile       = Join-Path $repo 'logs\deploy.log'
$containerName = 'cicd-env-satisfactory'
$PullImage     = $false   # バックアップ手順の整備前は $false のままにする (docs/07 の 3.2)
$HealthTimeoutSec = 300

# Discord への送信関数 (ファイルがなくてもデプロイは続行する)
$notifier = Join-Path $repo 'scripts\maintenance\Send-Discord.ps1'
if (Test-Path $notifier) { . $notifier }

function Write-Log([string]$Message) {
    $line = '{0} {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -Path $logFile -Value $line -Encoding utf8
}

# 失敗を記録して Discord へ通知し、終了コード 1 で終了する。
# 通知にはコマンドの出力を含めない (環境の値が含まれる可能性があるため)。詳細は deploy.log を見る。
# 通知が失敗しても、デプロイの結果 (終了コード) は変えない。
function Stop-Deploy([string]$Step, [string]$Detail) {
    Write-Log "中止: $Step ($Detail)"
    Write-Log '--- デプロイ中止 ---'
    if (Get-Command Send-DiscordMessage -ErrorAction SilentlyContinue) {
        $message = '🚨 デプロイが失敗した ({0})。工程: {1} / {2}。詳細は logs\deploy.log を参照' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Step, $Detail
        try {
            if (Send-DiscordMessage $repo $message) { Write-Log '失敗の通知をDiscordへ送信した' }
            else { Write-Log '警告: 失敗の通知をDiscordへ送信できなかった' }
        } catch {
            Write-Log '警告: 失敗の通知で例外が発生した'
        }
    }
    exit 1
}

function Invoke-Native([string]$Name, [scriptblock]$Command) {
    $output = & $Command 2>&1 | Out-String
    $code = $LASTEXITCODE
    if ($code -ne 0) {
        Write-Log "失敗: $Name (終了コード $code)"
        if ($output.Trim()) { Write-Log $output.Trim() }
        Stop-Deploy $Name "終了コード $code"
    }
    Write-Log "成功: $Name"
}

Set-Location $repo
New-Item -ItemType Directory -Force (Split-Path $logFile) | Out-Null
Write-Log '--- デプロイ開始 ---'

# 1. Docker Desktop の起動を最大5分待つ (ログオン直後の実行に備える)
$ready = $false
for ($i = 0; $i -lt 30; $i++) {
    docker info *> $null
    if ($LASTEXITCODE -eq 0) { $ready = $true; break }
    Start-Sleep -Seconds 10
}
if (-not $ready) { Stop-Deploy 'Docker起動待ち' 'Dockerが起動していない' }

# 2. main ブランチで、未コミットの変更がないことを確認する
$branch = git branch --show-current
if ($branch -ne 'main') { Stop-Deploy 'ブランチの確認' "mainではない($branch)" }
if (git status --porcelain) { Stop-Deploy '変更の確認' '未コミットの変更がある' }

$c = @('--env-file', '.env', '-f', 'compose/docker-compose.yml')

# 3. 最新を取り込む
Invoke-Native 'git pull' { git pull --ff-only }

# 4. 設定を検証する
Invoke-Native 'docker compose config' { docker compose @c config -q }

# 5. 更新前のバックアップ。手順 (docs/05_Backup.md) の整備後に scripts\backup\backup.ps1 を置く。
#    失敗したら更新しない。
$backupScript = Join-Path $repo 'scripts\backup\backup.ps1'
if (Test-Path $backupScript) {
    Invoke-Native 'backup' { & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $backupScript }
} else {
    Write-Log '警告: backup.ps1 が未配置のため、バックアップなしで続行する'
}

# 6. イメージの取得 (既定は無効)
if ($PullImage) { Invoke-Native 'docker compose pull' { docker compose @c pull } }

# 7. 起動 (変更がなければ何もしない)
Invoke-Native 'docker compose up -d' { docker compose @c up -d }

# 8. コンテナが healthy になるのを待つ
$status = ''
$deadline = (Get-Date).AddSeconds($HealthTimeoutSec)
while ((Get-Date) -lt $deadline) {
    $status = (docker inspect --format '{{.State.Health.Status}}' $containerName 2>$null)
    if ($status -eq 'healthy') { break }
    Start-Sleep -Seconds 10
}
if ($status -ne 'healthy') {
    Stop-Deploy 'healthy待ち' "${HealthTimeoutSec}秒以内にhealthyにならなかった (状態: $status)"
}
Write-Log '成功: healthy'

Write-Log '--- デプロイ終了 ---'
