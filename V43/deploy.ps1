#Requires -Version 7
# deploy.ps1 (V43, VG)
# Bygger Novatrix publiceringskedja från kod:
#   bucket -> grupper och användare -> rollen novatrix-publicera -> rollen novatrix-ec2-webb -> server
# Kör:  .\deploy.ps1   (inloggad som Simon-admin med "aws login")
# Finns delar redan kvar från en tidigare körning? Kör .\destroy.ps1 först.

. (Join-Path $PSScriptRoot "installningar.ps1")

# Kör ett aws-kommando. Misslyckas det stoppar hela skriptet direkt.
function Kor-Aws {
    $Svar = & aws @args
    if ($LASTEXITCODE -ne 0) {
        Write-Host "STOPP: aws $($args[0]) $($args[1]) misslyckades. Läs felet ovanför." -ForegroundColor Red
        Write-Host "Kör .\destroy.ps1 och sedan .\deploy.ps1 igen." -ForegroundColor Red
        exit 1
    }
    return $Svar
}

# Läser en fil och fyller i kontonummer, bucketnamn och region.
# Resultatet hamnar i en tillfällig fil, så kontonumret står aldrig i repot.
$TmpMapp = Join-Path ([IO.Path]::GetTempPath()) "novatrix-v43"
New-Item -ItemType Directory -Force -Path $TmpMapp | Out-Null
function Fyll-I([string]$Fil) {
    $Text = Get-Content -Path (Join-Path $PSScriptRoot $Fil) -Raw
    $Text = $Text.Replace("KONTO_ID", $Konto).Replace("BUCKETNAMN", $Bucket).Replace("REGION", $Region)
    $Ut = Join-Path $TmpMapp (Split-Path $Fil -Leaf)
    Set-Content -Path $Ut -Value $Text -NoNewline -Encoding utf8
    return "file://$Ut"
}

# ---------- 1. Inloggningen ----------
Write-Host "1/6 Kollar inloggningen..."
$Konto = Kor-Aws sts get-caller-identity --query Account --output text
$Jag   = Kor-Aws sts get-caller-identity --query Arn --output text
Write-Host "    Inloggad som: $Jag"

# ---------- 2. Bucketen ----------
Write-Host "2/6 Skapar bucketen $Bucket..."
Kor-Aws s3api create-bucket --bucket $Bucket --region $Region `
    --create-bucket-configuration "LocationConstraint=$Region" | Out-Null
# All publik åtkomst stängd. Det är standard, men nu står det i koden.
Kor-Aws s3api put-public-access-block --bucket $Bucket `
    --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" | Out-Null
# Första versionen av sidan läggs direkt i publicerat/
Kor-Aws s3 cp (Join-Path $PSScriptRoot "index.html") "s3://$Bucket/publicerat/index.html" --only-show-errors

# ---------- 3. Människorna ----------
# För varje team: policy -> grupp -> koppla policyn -> användare i gruppen
Write-Host "3/6 Skapar grupper och användare..."
foreach ($Team in $Teams) {
    $PolicyArn = Kor-Aws iam create-policy --policy-name $Team.Grupp `
        --policy-document (Fyll-I "policies\$($Team.Policy)") --query Policy.Arn --output text
    Kor-Aws iam create-group --group-name $Team.Grupp | Out-Null
    Kor-Aws iam attach-group-policy --group-name $Team.Grupp --policy-arn $PolicyArn
    Kor-Aws iam create-user --user-name $Team.Anvandare | Out-Null
    Kor-Aws iam add-user-to-group --user-name $Team.Anvandare --group-name $Team.Grupp
    Write-Host "    $($Team.Anvandare) i gruppen $($Team.Grupp)"
}

# ---------- 4. Rollen novatrix-publicera ----------
# Trust: identiteter i kontot får låna rollen, OM deras egen policy tillåter det.
# Bara gruppen novatrix-drift har en sådan policy.
Write-Host "4/6 Skapar rollen novatrix-publicera (drift lånar den)..."
Kor-Aws iam create-role --role-name novatrix-publicera `
    --assume-role-policy-document (Fyll-I "policies\trust-publicera.json") | Out-Null
Kor-Aws iam put-role-policy --role-name novatrix-publicera --policy-name publicera `
    --policy-document (Fyll-I "policies\publicera.json")

# ---------- 5. Rollen novatrix-ec2-webb ----------
Write-Host "5/6 Skapar rollen novatrix-ec2-webb (servern läser publicerade sidor)..."
Kor-Aws iam create-role --role-name novatrix-ec2-webb `
    --assume-role-policy-document (Fyll-I "policies\trust-ec2.json") | Out-Null
Kor-Aws iam put-role-policy --role-name novatrix-ec2-webb --policy-name ec2-webb `
    --policy-document (Fyll-I "policies\ec2-webb.json")
# En server kan inte bära en roll direkt. Rollen läggs i en instance profile.
Kor-Aws iam create-instance-profile --instance-profile-name novatrix-ec2-webb | Out-Null
Kor-Aws iam add-role-to-instance-profile --instance-profile-name novatrix-ec2-webb --role-name novatrix-ec2-webb

# ---------- 6. Servern ----------
Write-Host "6/6 Startar servern $ServerName med rollen..."
$UserData = Fyll-I "user-data-s3.sh"
# En ny instance profile tar några sekunder innan EC2 hittar den. Därför försöker vi igen.
$InstanceId = $null
for ($Forsok = 1; $Forsok -le 6; $Forsok++) {
    $InstanceId = aws ec2 run-instances `
        --region $Region `
        --image-id $Ami `
        --instance-type $InstanceType `
        --key-name $KeyName `
        --security-group-ids $SecurityGroup `
        --iam-instance-profile "Name=novatrix-ec2-webb" `
        --user-data $UserData `
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$ServerName},{Key=Project,Value=Novatrix}]" `
        --query "Instances[0].InstanceId" `
        --output text
    if ($LASTEXITCODE -eq 0) { break }
    $InstanceId = $null
    Write-Host "    Rollen är inte redo än. Försöker igen om 10 sekunder ($Forsok/6)..."
    Start-Sleep -Seconds 10
}
if (-not $InstanceId) {
    Write-Host "STOPP: kunde inte starta servern. Läs felet ovanför." -ForegroundColor Red
    exit 1
}

Write-Host "    Väntar tills servern är Running (ca 1 minut)..."
Kor-Aws ec2 wait instance-running --region $Region --instance-ids $InstanceId
$Ip = Kor-Aws ec2 describe-instances --region $Region --instance-ids $InstanceId `
    --query "Reservations[0].Instances[0].PublicIpAddress" --output text

# Städa de tillfälliga filerna (de innehåller kontonumret)
Remove-Item $TmpMapp -Recurse -Force

Write-Host ""
Write-Host "Klart! Hela kedjan är byggd." -ForegroundColor Green
Write-Host "    Server:    $ServerName ($InstanceId)"
Write-Host "    Publik IP: $Ip"
Write-Host "    Vänta 1-2 minuter, öppna sedan http://$Ip"
Write-Host "    Testa behörigheterna med: .\test.ps1"
