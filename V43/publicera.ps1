#Requires -Version 7
# publicera.ps1 (V43, VG)
# Drifts verktyg: lånar rollen novatrix-publicera och kopierar utkastet till publicerat/.
# Bara den som får låna rollen kan köra det här: gruppen novatrix-drift (och admin).

. (Join-Path $PSScriptRoot "installningar.ps1")

$Konto = aws sts get-caller-identity --query Account --output text
if ($LASTEXITCODE -ne 0) { Write-Host "Du är inte inloggad. Kör: aws login"; exit 1 }
$RollArn = "arn:aws:iam::${Konto}:role/novatrix-publicera"

# ---------- 1. Låna rollen ----------
Write-Host "1/3 Lånar rollen novatrix-publicera..."
$Kort = aws sts assume-role --role-arn $RollArn --role-session-name "publicera-sidan" `
    --query Credentials --output json | ConvertFrom-Json
if (-not $Kort) {
    Write-Host "STOPP: fick inte låna rollen. Läs felet ovanför." -ForegroundColor Red
    exit 1
}

try {
    # Rollens tillfälliga nycklar gäller bara medan skriptet körs
    $env:AWS_ACCESS_KEY_ID     = $Kort.AccessKeyId
    $env:AWS_SECRET_ACCESS_KEY = $Kort.SecretAccessKey
    $env:AWS_SESSION_TOKEN     = $Kort.SessionToken
    $Vem = aws sts get-caller-identity --query Arn --output text
    Write-Host "    Nu är jag: $Vem"

    # ---------- 2. Hämta utkastet ----------
    Write-Host "2/3 Hämtar utkast/index.html..."
    $Fil = Join-Path ([IO.Path]::GetTempPath()) "novatrix-utkast.html"
    aws s3 cp "s3://$Bucket/utkast/index.html" $Fil --only-show-errors
    if ($LASTEXITCODE -ne 0) { throw "Kunde inte hämta utkastet. Finns utkast/index.html i bucketen?" }

    # ---------- 3. Publicera ----------
    Write-Host "3/3 Publicerar till publicerat/index.html..."
    aws s3 cp $Fil "s3://$Bucket/publicerat/index.html" --only-show-errors
    if ($LASTEXITCODE -ne 0) { throw "Kunde inte publicera." }
    Remove-Item $Fil

    Write-Host ""
    Write-Host "Klart! Utkastet är publicerat." -ForegroundColor Green
    Write-Host "Hämta den nya sidan på servern (via SSH):"
    Write-Host "    sudo aws s3 cp s3://$Bucket/publicerat/index.html /var/www/html/index.html"
}
finally {
    # Glöm rollens nycklar. Då är jag mig själv igen.
    Remove-Item Env:AWS_ACCESS_KEY_ID, Env:AWS_SECRET_ACCESS_KEY, Env:AWS_SESSION_TOKEN -ErrorAction SilentlyContinue
}
