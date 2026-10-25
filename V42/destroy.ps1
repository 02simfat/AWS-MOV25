# destroy.ps1 (V42, VG)
# Tar bort instansen som deploy.ps1 skapade.
# Kör från terminalen i VS Code:  .\destroy.ps1
# Rör bara instanser som heter Novatrix-web-cli, inte din vanliga Novatrix-web.

$Region = "eu-north-1"
$Name   = "Novatrix-web-cli"

# ---------- 1. Hitta instansen ----------
# Letar efter instanser med rätt namn som inte redan är borttagna
$Ids = aws ec2 describe-instances `
    --region $Region `
    --filters "Name=tag:Name,Values=$Name" "Name=instance-state-name,Values=pending,running,stopping,stopped" `
    --query "Reservations[].Instances[].InstanceId" `
    --output text

if (-not $Ids) { Write-Host "Hittade ingen instans som heter $Name. Inget att ta bort."; exit 0 }

# Om det finns flera blir det en lista
$IdList = $Ids -split "\s+"
Write-Host "Hittade: $IdList"

# ---------- 2. Fråga först ----------
$Svar = Read-Host "Vill du ta bort den? Skriv ja"
if ($Svar -ne "ja") { Write-Host "Avbrutet. Inget togs bort."; exit 0 }

# ---------- 3. Ta bort och vänta ----------
aws ec2 terminate-instances --region $Region --instance-ids $IdList --output text | Out-Null
Write-Host "Tar bort... (ca 1 minut)"
aws ec2 wait instance-terminated --region $Region --instance-ids $IdList
Write-Host "Klart! $Name är borttagen."
