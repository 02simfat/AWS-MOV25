#Requires -Version 7
# destroy.ps1 (V43, VG)
# River allt som deploy.ps1 byggde, i omvänd ordning.
# Det som redan är borta hoppas över, så skriptet går att köra flera gånger.
# Rör inte G-delen från konsolen (Utveckling, drift, Novatrix-ec2-S3-Read, novatrix-bucket-01).

. (Join-Path $PSScriptRoot "installningar.ps1")

# Kör ett aws-kommando som tar bort något, och skriver ut hur det gick.
# Första ordet är en beskrivning, resten är aws-kommandot.
function Ta-Bort {
    $Vad  = $args[0]
    $Rest = $args[1..($args.Count - 1)]
    & aws @Rest 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { Write-Host "    [x] $Vad" }
    else { Write-Host "    [-] $Vad (fanns inte, hoppar över)" -ForegroundColor DarkGray }
}

$Konto = aws sts get-caller-identity --query Account --output text
if ($LASTEXITCODE -ne 0) { Write-Host "Du är inte inloggad. Kör: aws login"; exit 1 }

Write-Host "Det här tar bort $ServerName, rollerna, grupperna, användarna och bucketen $Bucket."
$Svar = Read-Host "Vill du fortsätta? Skriv ja"
if ($Svar -ne "ja") { Write-Host "Avbrutet. Inget togs bort."; exit 0 }

# ---------- 1. Servern först, den använder rollen novatrix-ec2-webb ----------
Write-Host "1/5 Servern"
$Ids = aws ec2 describe-instances --region $Region `
    --filters "Name=tag:Name,Values=$ServerName" "Name=instance-state-name,Values=pending,running,stopping,stopped" `
    --query "Reservations[].Instances[].InstanceId" --output text
if ($Ids) {
    $IdLista = $Ids -split "\s+"
    aws ec2 terminate-instances --region $Region --instance-ids $IdLista | Out-Null
    Write-Host "    Väntar tills servern är borta (ca 1 minut)..."
    aws ec2 wait instance-terminated --region $Region --instance-ids $IdLista
    Write-Host "    [x] servern $IdLista"
} else {
    Write-Host "    [-] servern (fanns inte, hoppar över)" -ForegroundColor DarkGray
}

# ---------- 2. Rollen novatrix-ec2-webb ----------
Write-Host "2/5 Rollen novatrix-ec2-webb"
Ta-Bort "rollen ur instance profile" iam remove-role-from-instance-profile --instance-profile-name novatrix-ec2-webb --role-name novatrix-ec2-webb
Ta-Bort "instance profile"           iam delete-instance-profile --instance-profile-name novatrix-ec2-webb
Ta-Bort "rollens policy"             iam delete-role-policy --role-name novatrix-ec2-webb --policy-name ec2-webb
Ta-Bort "rollen"                     iam delete-role --role-name novatrix-ec2-webb

# ---------- 3. Rollen novatrix-publicera ----------
Write-Host "3/5 Rollen novatrix-publicera"
Ta-Bort "rollens policy" iam delete-role-policy --role-name novatrix-publicera --policy-name publicera
Ta-Bort "rollen"         iam delete-role --role-name novatrix-publicera

# ---------- 4. Människorna: användare, grupp, sist policyn ----------
Write-Host "4/5 Grupper och användare"
foreach ($Team in $Teams) {
    $PolicyArn = "arn:aws:iam::${Konto}:policy/$($Team.Grupp)"
    Ta-Bort "$($Team.Anvandare) ur gruppen"      iam remove-user-from-group --user-name $Team.Anvandare --group-name $Team.Grupp
    Ta-Bort "lösenord för $($Team.Anvandare)"    iam delete-login-profile --user-name $Team.Anvandare
    Ta-Bort "användaren $($Team.Anvandare)"      iam delete-user --user-name $Team.Anvandare
    Ta-Bort "policyn från $($Team.Grupp)"        iam detach-group-policy --group-name $Team.Grupp --policy-arn $PolicyArn
    Ta-Bort "gruppen $($Team.Grupp)"             iam delete-group --group-name $Team.Grupp
    Ta-Bort "policyn $($Team.Grupp)"             iam delete-policy --policy-arn $PolicyArn
}

# ---------- 5. Bucketen, --force tömmer den först ----------
Write-Host "5/5 Bucketen"
Ta-Bort "bucketen $Bucket med allt innehåll" s3 rb "s3://$Bucket" --force

Write-Host ""
Write-Host "Klart! Allt från deploy.ps1 är borttaget." -ForegroundColor Green
