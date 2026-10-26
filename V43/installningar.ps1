# installningar.ps1 (V43, VG)
# Alla värden som kan behöva bytas står här, på ett ställe.
# deploy.ps1, destroy.ps1, test.ps1 och publicera.ps1 läser den här filen.

$Region        = "eu-north-1"                 # Europe (Stockholm)
$Bucket        = "novatrix-sajt-02simfat-01"  # Måste vara unikt i hela AWS
$KeyName       = "novatrix-key"               # Key pair som redan finns i kontot
$SecurityGroup = "sg-0c5e9571d95eecce7"       # launch-wizard-1 (port 22 och 80)
$InstanceType  = "t3.micro"                   # Free tier
$ServerName    = "Novatrix-web-vg"

# Senaste Amazon Linux 2023. AWS slår upp rätt AMI-id själv.
$Ami = "resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"

# Novatrix team. Ett nytt team = en ny rad här + en ny JSON-fil i policies/.
$Teams = @(
    @{ Grupp = "novatrix-utveckling"; Anvandare = "dev-lisa"; Policy = "utveckling.json" }
    @{ Grupp = "novatrix-drift";      Anvandare = "ops-omar"; Policy = "drift.json" }
)
