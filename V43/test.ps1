#Requires -Version 7
# test.ps1 (V43, VG)
# Testar alla behörigheter i kedjan med IAM Policy Simulator.
# Simulatorn svarar vad AWS skulle säga, utan att något görs på riktigt.
# Då behöver testanvändarna inga lösenord eller nycklar.
# Kör efter .\deploy.ps1

. (Join-Path $PSScriptRoot "installningar.ps1")

$Konto = aws sts get-caller-identity --query Account --output text
if ($LASTEXITCODE -ne 0) { Write-Host "Du är inte inloggad. Kör: aws login"; exit 1 }

# Vilka som testas
$Lisa = "arn:aws:iam::${Konto}:user/dev-lisa"
$Omar = "arn:aws:iam::${Konto}:user/ops-omar"
$Publ = "arn:aws:iam::${Konto}:role/novatrix-publicera"
$Webb = "arn:aws:iam::${Konto}:role/novatrix-ec2-webb"

# Vad som testas
$Utkast     = "arn:aws:s3:::$Bucket/utkast/index.html"
$Publicerat = "arn:aws:s3:::$Bucket/publicerat/index.html"
$Servrar    = "arn:aws:ec2:${Region}:${Konto}:instance/*"

# Varje rad: vem, vad, vilken resurs, och vad jag väntar mig (Ja = tillåtet, Nej = nekat)
$Tester = @(
    @{ Vem = "dev-lisa";   Arn = $Lisa; Test = "Läsa den publicerade sidan";   Action = "s3:GetObject";           Resurs = $Publicerat; Vantat = "Ja" }
    @{ Vem = "dev-lisa";   Arn = $Lisa; Test = "Ladda upp ett utkast";         Action = "s3:PutObject";           Resurs = $Utkast;     Vantat = "Ja" }
    @{ Vem = "dev-lisa";   Arn = $Lisa; Test = "Publicera själv";              Action = "s3:PutObject";           Resurs = $Publicerat; Vantat = "Nej" }
    @{ Vem = "dev-lisa";   Arn = $Lisa; Test = "Radera ett utkast";            Action = "s3:DeleteObject";        Resurs = $Utkast;     Vantat = "Nej" }
    @{ Vem = "dev-lisa";   Arn = $Lisa; Test = "Låna publicera-rollen";        Action = "sts:AssumeRole";         Resurs = $Publ;       Vantat = "Nej" }
    @{ Vem = "ops-omar";   Arn = $Omar; Test = "Låna publicera-rollen";        Action = "sts:AssumeRole";         Resurs = $Publ;       Vantat = "Ja" }
    @{ Vem = "ops-omar";   Arn = $Omar; Test = "Publicera utan rollen";        Action = "s3:PutObject";           Resurs = $Publicerat; Vantat = "Nej" }
    @{ Vem = "ops-omar";   Arn = $Omar; Test = "Starta om en Novatrix-server"; Action = "ec2:RebootInstances";    Resurs = $Servrar;    Vantat = "Ja";  Tagg = "Novatrix" }
    @{ Vem = "ops-omar";   Arn = $Omar; Test = "Radera en Novatrix-server";    Action = "ec2:TerminateInstances"; Resurs = $Servrar;    Vantat = "Nej"; Tagg = "Novatrix" }
    @{ Vem = "publicera";  Arn = $Publ; Test = "Läsa utkastet";                Action = "s3:GetObject";           Resurs = $Utkast;     Vantat = "Ja" }
    @{ Vem = "publicera";  Arn = $Publ; Test = "Skriva till publicerat";       Action = "s3:PutObject";           Resurs = $Publicerat; Vantat = "Ja" }
    @{ Vem = "publicera";  Arn = $Publ; Test = "Ändra utkastet";               Action = "s3:PutObject";           Resurs = $Utkast;     Vantat = "Nej" }
    @{ Vem = "publicera";  Arn = $Publ; Test = "Radera den publicerade sidan"; Action = "s3:DeleteObject";        Resurs = $Publicerat; Vantat = "Nej" }
    @{ Vem = "ec2-webb";   Arn = $Webb; Test = "Läsa den publicerade sidan";   Action = "s3:GetObject";           Resurs = $Publicerat; Vantat = "Ja" }
    @{ Vem = "ec2-webb";   Arn = $Webb; Test = "Läsa utkastet";                Action = "s3:GetObject";           Resurs = $Utkast;     Vantat = "Nej" }
    @{ Vem = "ec2-webb";   Arn = $Webb; Test = "Skriva till publicerat";       Action = "s3:PutObject";           Resurs = $Publicerat; Vantat = "Nej" }
)

Write-Host "Kör $($Tester.Count) tester i Policy Simulator..."
$Nr = 0
$Resultat = foreach ($T in $Tester) {
    $Nr++
    $Argument = @(
        "iam", "simulate-principal-policy",
        "--policy-source-arn", $T.Arn,
        "--action-names", $T.Action,
        "--resource-arns", $T.Resurs,
        "--query", "EvaluationResults[0].EvalDecision",
        "--output", "text"
    )
    # Drift får bara styra servrar med taggen Project=Novatrix. Simulatorn behöver veta taggen.
    if ($T.Tagg) {
        $Argument += @("--context-entries", "ContextKeyName=aws:ResourceTag/Project,ContextKeyValues=$($T.Tagg),ContextKeyType=string")
    }
    $Svar = aws @Argument
    $Fick = if ($Svar -eq "allowed") { "Ja" } else { "Nej" }
    [PSCustomObject]@{
        "Nr"       = $Nr
        "Vem"      = $T.Vem
        "Test"     = $T.Test
        "Väntat"   = $T.Vantat
        "Fick"     = $Fick
        "Resultat" = if ($Fick -eq $T.Vantat) { "OK" } else { "FEL" }
    }
}

$Resultat | Format-Table -AutoSize
$Fel = @($Resultat | Where-Object Resultat -eq "FEL").Count
if ($Fel -eq 0) {
    Write-Host "Alla $($Resultat.Count) tester blev som jag väntade mig." -ForegroundColor Green
} else {
    Write-Host "$Fel tester blev INTE som jag väntade mig. Kolla raderna med FEL." -ForegroundColor Red
}
