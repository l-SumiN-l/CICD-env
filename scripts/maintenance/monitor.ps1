# CICD-ENV monitor script (Windows PowerShell 5.1 compatible)
# コンテナの状態を確認し、状態が変わったとき (異常・復旧) と、1時間に1回の定期通知で Discord へ通知する。docs/06_Monitoring.md を参照。
# このファイルは UTF-8 (BOM 付き) で保存すること。
#
# -Test    : テストメッセージを1件送って終了する (状態は確認しない)
# -DryRun  : Discord へは送らず、送るはずのメッセージを画面に出す (状態の遷移の確認用)
# -LanIp   : LAN側のIPを指定する (省略時は自動取得)。LAN側のIP経由で HealthCheck を確認し、IPが変わったら通知する
# -StateFile :状態ファイルの場所。検証時に本番の状態ファイルを汚さないために指定する
# -ContainerName : 監視するコンテナ名。存在しない名前を指定すると、異常時の動きを確認できる
param(
    [switch]$Test,
    [switch]$DryRun,
    [string]$StateFile,
    [string]$ContainerName = 'cicd-env-satisfactory',
    [string]$LanIp   # LAN側のIPアドレス。省略すると自動で取得する (検証用。通知やログには値を出さない)
)

$repo          = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$logFile       = Join-Path $repo 'logs\monitor.log'
$deployLog     = Join-Path $repo 'logs\deploy.log'
$FailThreshold = 3     # 連続でこの回数、異常だったら通知する (5分間隔なら約15分)
$DeployGraceMin = 30   # デプロイの実行中とみなす最大の時間 (分)
$timeFmt       = 'yyyy-MM-dd HH:mm:ss'
if (-not $StateFile) { $StateFile = Join-Path $repo 'logs\monitor-state.json' }

. (Join-Path $PSScriptRoot 'Send-Discord.ps1')

function Write-Log([string]$Message) {
    $line = '{0} {1}' -f (Get-Date -Format $timeFmt), $Message
    Add-Content -Path $logFile -Value $line -Encoding utf8
}

function Send-Notice([string]$Message) {
    if ($DryRun) { Write-Host "[DryRun] $Message"; return $true }
    $ok = Send-DiscordMessage $repo $Message
    if ($ok) { Write-Log "通知を送信した: $Message" } else { Write-Log "通知の送信に失敗した: $Message" }
    return $ok
}

function Format-Duration([datetime]$From) {
    $span = (Get-Date) - $From
    if ($span.TotalHours -ge 1) { return '{0}時間{1}分' -f [int][math]::Floor($span.TotalHours), $span.Minutes }
    return '{0}分' -f [int][math]::Floor($span.TotalMinutes)
}

# LAN側のIPv4アドレスを返す。既定ゲートウェイを持つ有効なアダプターのうち、WSL・Dockerの仮想アダプターを除く。
# 取得できなければ空を返す。
function Get-LanIp {
    $cfg = Get-NetIPConfiguration -ErrorAction SilentlyContinue |
        Where-Object { $_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq 'Up' -and $_.InterfaceAlias -notmatch 'vEthernet|WSL|Docker' } |
        Select-Object -First 1
    if ($cfg -and $cfg.IPv4Address) { return [string]$cfg.IPv4Address[0].IPAddress }
    return ''
}

# LAN側のIPアドレス経由で、管理用APIの HealthCheck を呼ぶ。正常なら $true。
# 自己署名の証明書を受け入れる設定は、この呼び出しの間だけ有効にする (Discordへの送信に影響させないため)。
# 失敗の理由にはIPが含まれる可能性があるため、例外の種類だけを返す。
function Test-LanHealth([string]$Ip, [int]$Port) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    [Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
    try {
        $res = Invoke-RestMethod -Uri ('https://{0}:{1}/api/v1' -f $Ip, $Port) -Method Post `
            -Body '{"function":"HealthCheck","data":{"clientCustomData":""}}' `
            -ContentType 'application/json' -TimeoutSec 10
        return ($res.data.health -eq 'healthy')
    } catch {
        $script:lanError = $_.Exception.GetType().Name
        return $false
    } finally {
        [Net.ServicePointManager]::ServerCertificateValidationCallback = $null
    }
}

New-Item -ItemType Directory -Force (Split-Path $logFile) | Out-Null
New-Item -ItemType Directory -Force (Split-Path $StateFile) | Out-Null

if ($Test) {
    [void](Send-Notice ('[テスト] CICD-ENV の監視通知のテスト ({0})' -f (Get-Date -Format $timeFmt)))
    exit 0
}

# デプロイの実行中は、再作成による一時的な停止を異常とみなさない
if (Test-Path $deployLog) {
    $item = Get-Item $deployLog
    $last = Get-Content -Path $deployLog -Tail 1 -Encoding utf8
    $running = $last -notmatch 'デプロイ(終了|中止)'
    if ($running -and $item.LastWriteTime -gt (Get-Date).AddMinutes(-$DeployGraceMin)) {
        Write-Log 'デプロイの実行中のため、今回の確認をスキップした'
        exit 0
    }
}

# 状態の読み込み (初回・壊れている場合は初期状態)
$state = [pscustomobject]@{ state = 'unknown'; failCount = 0; downSince = ''; lastReport = ''; lastIp = '' }
if (Test-Path $StateFile) {
    try {
        $loaded = Get-Content -Path $StateFile -Raw -Encoding utf8 | ConvertFrom-Json
        $state = [pscustomobject]@{
            state      = [string]$loaded.state
            failCount  = [int]$loaded.failCount
            downSince  = [string]$loaded.downSince
            lastReport = [string]$loaded.lastReport   # 旧形式の状態ファイルには無いため、空になる
            lastIp     = [string]$loaded.lastIp       # 同上。前回確認したLAN側のIP (状態ファイルはGit管理対象外)
        }
    }
    catch { Write-Log '状態ファイルが壊れていたため、初期状態に戻した' }
}

# コンテナの状態を取得する (Docker Desktop が止まっている場合や、コンテナがない場合は空になる)
$status = ''
try { $status = (docker inspect --format '{{.State.Health.Status}}' $ContainerName 2>$null) } catch { }
if ($LASTEXITCODE -ne 0 -or -not $status) { $status = 'unavailable' }

# LAN側のIP経由で HealthCheck を確認する。コンテナが healthy のときだけ行い、応答がなければ異常とする。
# (コンテナの内側からの確認では、ポートの転送や、PCのIPの変化による接続の不具合に気づけないため)
$ip = if ($LanIp) { $LanIp } else { Get-LanIp }
if ($status -eq 'healthy') {
    $port = Get-EnvValue $repo 'SATISFACTORY_GAME_PORT'
    if (-not $port) { $port = 7777 }
    if (-not $ip) {
        Write-Log 'LAN側のIPアドレスを取得できなかった'
        $status = 'LAN側のIPなし'
    } else {
        $script:lanError = ''
        if (-not (Test-LanHealth $ip ([int]$port))) {
            Write-Log "LAN経由のHealthCheckに失敗した ($script:lanError)"
            $status = 'LAN経由の応答なし'
        }
    }
}
$ok = ($status -eq 'healthy')

# LAN側のIPが変わったら、1回だけ通知する (IPの値は通知にもログにも出さない)
if ($ip) {
    if ($state.lastIp -and $state.lastIp -ne $ip) {
        $sentIp = Send-Notice ('ℹ️ サーバーを動かすPCのLAN側のIPアドレスが変更された ({0})。接続先の設定を確認すること' -f (Get-Date -Format $timeFmt))
        if ($sentIp) { $state.lastIp = $ip }
    } else {
        $state.lastIp = $ip
    }
}

$alerted = $false   # 今回、異常・復旧の通知を送ったか (同じ回に定期通知を重ねない)
if ($ok) {
    if ($state.state -eq 'down') {
        $since = [datetime]::ParseExact($state.downSince, $timeFmt, $null)
        [void](Send-Notice ('✅ Satisfactoryサーバーが復旧した ({0})。停止していた時間: 約{1}' -f (Get-Date -Format $timeFmt), (Format-Duration $since)))
        Write-Log "復旧 (状態: $status)"
        $alerted = $true
    }
    $state.state = 'up'; $state.failCount = 0; $state.downSince = ''
} else {
    $state.failCount = [int]$state.failCount + 1
    Write-Log "異常を検知 ($($state.failCount) 回目, 状態: $status)"
    if ($state.failCount -ge $FailThreshold -and $state.state -ne 'down') {
        $state.downSince = Get-Date -Format $timeFmt
        [void](Send-Notice ('🚨 Satisfactoryサーバーが異常 ({0})。状態:{1}' -f $state.downSince, $status))
        $state.state = 'down'
        $alerted = $true
    }
}

# 定期通知: 1時間に1回、正常・異常のどちらでも現在の状態を送る。
# 「yyyy-MM-dd HH」が前回の通知と違う最初の実行で送る (毎時0分ごろ)。送信に失敗したら、次の実行で再試行する。
$hourKey = Get-Date -Format 'yyyy-MM-dd HH'
if ($state.lastReport -ne $hourKey) {
    $sent = $true
    if (-not $alerted) {
        $now = Get-Date -Format $timeFmt
        if ($ok) {
            $report = '✅ [定期] Satisfactoryサーバーは稼働中 ({0})。LAN経由のHealthCheckは正常 (ゲームへの接続そのものは未確認)' -f $now
        } elseif ($state.state -eq 'down') {
            $since = [datetime]::ParseExact($state.downSince, $timeFmt, $null)
            $report = '🚨 [定期] Satisfactoryサーバーは停止中 ({0})。状態:{1}。停止から約{2}' -f $now, $status, (Format-Duration $since)
        } else {
            $report = '⚠️ [定期] Satisfactoryサーバーの状態が正常でない ({0})。状態:{1}。連続{2}回目 (異常の通知は連続{3}回で送る)' -f $now, $status, $state.failCount, $FailThreshold
        }
        $sent = Send-Notice $report
    }
    if ($sent) { $state.lastReport = $hourKey }
}

$state | ConvertTo-Json -Compress | Set-Content -Path $StateFile -Encoding utf8
