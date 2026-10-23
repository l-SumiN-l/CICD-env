# Discord Webhook への送信関数 (Windows PowerShell 5.1 compatible)
# 使い方: . (Join-Path $PSScriptRoot 'Send-Discord.ps1')
# Webhook URL は .env の DISCORD_WEBHOOK_URL から読む。URL はログや画面に出さない。
# このファイルは UTF-8 (BOM 付き) で保存すること。

function Get-EnvValue([string]$Repo, [string]$Name) {
    $envFile = Join-Path $Repo '.env'
    if (-not (Test-Path $envFile)) { return $null }
    foreach ($line in Get-Content -Path $envFile -Encoding utf8) {
        if ($line -match ('^\s*' + [regex]::Escape($Name) + '\s*=\s*(.*?)\s*$')) {
            return $Matches[1].Trim('"').Trim("'")
        }
    }
    return $null
}

# 送信に成功したら $true、失敗または URL 未設定なら $false を返す。
# 失敗の理由は Error プロパティ相当のメッセージを Write-Warning で出す (URL は含めない)。
function Send-DiscordMessage([string]$Repo, [string]$Message) {
    $url = Get-EnvValue $Repo 'DISCORD_WEBHOOK_URL'
    if (-not $url) {
        Write-Warning 'DISCORD_WEBHOOK_URL が .env に設定されていないため送信しない'
        return $false
    }
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $json  = @{ content = $Message } | ConvertTo-Json -Compress
    $bytes = [Text.Encoding]::UTF8.GetBytes($json)   # PowerShell 5.1 で日本語を正しく送るため UTF-8 に変換する
    try {
        Invoke-RestMethod -Uri $url -Method Post -Body $bytes `
            -ContentType 'application/json; charset=utf-8' -TimeoutSec 15 | Out-Null
        return $true
    } catch {
        $status = ''
        if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }
        Write-Warning ('Discordへの送信に失敗した (HTTP {0} {1})' -f $status, $_.Exception.GetType().Name)
        return $false
    }
}
