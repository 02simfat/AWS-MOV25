# deploy.ps1 (V42, VG)
# Skapar Novatrix webbserver i AWS från kod.
# Kör från terminalen i VS Code:  .\deploy.ps1
# Krav: AWS CLI är installerat och du är inloggad med "aws login".

# ---------- Inställningar: byt här om miljön är en annan ----------
$Region        = "eu-north-1"            # Europe (Stockholm)
$Name          = "Novatrix-web-cli"      # Eget namn, så destroy.ps1 inte rör Novatrix-web
$InstanceType  = "t3.micro"              # Free tier
$KeyName       = "novatrix-key"          # Key pair som redan finns i AWS
$SecurityGroup = "sg-0c5e9571d95eecce7"  # launch-wizard-1 (port 22 och 80)
$UserData      = "$PSScriptRoot\user-data.sh"

# Senaste Amazon Linux 2023. AWS slår upp rätt AMI-id själv, så det blir aldrig gammalt.
$Ami = "resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"

# ---------- 1. Kolla inloggningen ----------
Write-Host "1/4 Kollar att du är inloggad i AWS..."
aws sts get-caller-identity --query Account --output text
if ($LASTEXITCODE -ne 0) { Write-Host "Du är inte inloggad. Kör: aws login"; exit 1 }

# ---------- 2. Starta instansen ----------
Write-Host "2/4 Startar instansen $Name..."
$InstanceId = aws ec2 run-instances `
    --region $Region `
    --image-id $Ami `
    --instance-type $InstanceType `
    --key-name $KeyName `
    --security-group-ids $SecurityGroup `
    --user-data "file://$UserData" `
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$Name},{Key=Project,Value=Novatrix}]" `
    --query "Instances[0].InstanceId" `
    --output text
if ($LASTEXITCODE -ne 0) { Write-Host "Kunde inte starta instansen. Läs felet ovanför."; exit 1 }
Write-Host "    Instans-ID: $InstanceId"

# ---------- 3. Vänta tills den är igång ----------
Write-Host "3/4 Väntar tills instansen är Running (ca 1 minut)..."
aws ec2 wait instance-running --region $Region --instance-ids $InstanceId

# ---------- 4. Hämta den publika IP-adressen ----------
$PublicIp = aws ec2 describe-instances `
    --region $Region `
    --instance-ids $InstanceId `
    --query "Reservations[0].Instances[0].PublicIpAddress" `
    --output text

Write-Host "4/4 Klart!"
Write-Host "    Publik IP: $PublicIp"
Write-Host "    Vänta 1-2 minuter medan user data installerar webbservern."
Write-Host "    Öppna sedan: http://$PublicIp"
