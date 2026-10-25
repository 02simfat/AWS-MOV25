# AWS - Uppgift 1 (V42)

**Compute och kom igång**

- **Namn:** Simon Fatty
- **Kurs:** Amazon Web Services, MOV25
- **Repo:** https://github.com/02simfat/AWS-MOV25 (koden ligger i mappen `V42`)
- **Datum:** 2026-10-25

## Innehåll

1. Syfte
2. Översikt
3. Delmoment 1: GitHub-repo
4. Delmoment 2: EC2-instans
5. Delmoment 3: SSH och webbserver
6. Delmoment 4: Novatrix-sidan
7. Delmoment 5: Verifiering
8. Delmoment 6: Budget och kostnadskontroll
9. Säkerhet
10. Städning

---

## Syfte

Novatrix AB vill flytta sin webbplats till AWS. Den här veckan sätter jag upp en virtuell server (EC2) i AWS och driftsätter en enkel webbsida på den.

Servern är grunden för resten av kursen. Under kommande veckor bygger jag vidare med nätverk, databas, lagring, skalbarhet och monitorering.

## Översikt

Det här har jag byggt:

```
Min dator (PowerShell) ---- SSH, port 22 ----> EC2: Novatrix-web
                                                 Amazon Linux 2023
Webbläsare ---------------- HTTP, port 80 ---> httpd (Apache)
                                                 /var/www/html/index.html
```

- Jag loggar in på servern med **SSH** på port 22. Bara min IP-adress får göra det.
- Alla kan se webbsidan med **HTTP** på port 80.
- Webbservern **httpd** skickar sidan `index.html` till webbläsaren.

---

## Delmoment 1: GitHub-repo

Jag skapade ett publikt repo på GitHub som heter `AWS-MOV25`. Sen kopplade jag min lokala mapp `C:\AWS\MOV25-AWS` till repot.

```powershell
cd C:\AWS\MOV25-AWS
git init -b main
git remote add origin https://github.com/02simfat/AWS-MOV25.git
git pull origin main
git add .
git status
git commit -m "Mappstruktur V42-V49 och Novatrix-sida"
git push -u origin main
```

- `git init -b main` gör mappen till ett git-repo, med huvudgrenen `main`.
- `git remote add origin` kopplar mappen till mitt repo på GitHub.
- `git pull origin main` hämtar det som redan fanns på GitHub (README.md).
- `git status` visar vilka filer som ska med. Där kollade jag att ingen nyckel följde med.
- `git push -u origin main` skickar upp allt till GitHub.

Repot har en mapp per vecka:

```
AWS-MOV25/
├── README.md        (namn, kurs och lista över veckorna)
├── .gitignore       (stoppar nycklar från att hamna i repot)
├── V42/
│   ├── README.md    (den här redovisningen)
│   ├── index.html   (Novatrix-sidan)
│   └── Bilder-v42/  (skärmbilder)
├── V43/
...
└── V49/
```

I `.gitignore` finns bland annat raden `*.pem`. Den gör att min SSH-nyckel aldrig laddas upp till GitHub. Repot är publikt, så en uppladdad nyckel skulle låta vem som helst logga in på min server.

**Verifiering:** `git status` visade ingen `.pem`-fil, och alla mappar syns på GitHub.

---

## Delmoment 2: EC2-instans

Jag startade instansen i AWS-konsolen under **EC2 > Launch instances**.

| Inställning | Mitt val | Varför |
|---|---|---|
| Region | Europe (Stockholm), `eu-north-1` | Nära Novatrix, kort svarstid |
| Namn | `Novatrix-web` | Namnet visar vad servern gör |
| AMI | Amazon Linux 2023 | Krav i uppgiften. AWS egen Linux |
| Instanstyp | `t3.micro` | Ingår i free tier och räcker för en enkel webbsida |
| Key pair | `novatrix-key` (`.pem`) | Nyckeln jag loggar in med via SSH |
| Security group | `launch-wizard-1` | Brandväggen för instansen. AWS gav den namnet automatiskt |
| Availability Zone | `eu-north-1b` | Valdes av AWS |
| Publik IP | `16.171.137.177` | Adressen till webbsidan |

Nyckeln laddade jag ner en gång och flyttade till mappen `.ssh` i min hemmapp.

### Security group

| Port | Protokoll | Källa | Varför |
|---|---|---|---|
| 22 | TCP (SSH) | `90.226.119.19/32` | `/32` betyder en enda IP-adress. Bara jag kan logga in |
| 80 | TCP (HTTP) | `0.0.0.0/0` | Hela internet. Alla ska kunna se webbsidan |

![Security group med port 22 och 80](Bilder-v42/security-group.png)

**Verifiering:** Instansen har status **Running** och **3/3 checks passed**.

![Instansen Novatrix-web i EC2-konsolen](Bilder-v42/Instances.png)

---

## Delmoment 3: SSH och webbserver

### Ansluta med SSH

Jag anslöt från terminalen i VS Code (PowerShell):

```powershell
ssh -i $HOME\.ssh\novatrix-key.pem ec2-user@16.171.137.177
```

- `-i` talar om vilken nyckel som ska användas.
- `ec2-user` är standardanvändaren på Amazon Linux.

Sen kollade jag vem jag var inloggad som:

```bash
whoami
```

Svaret blev `ec2-user`.

### Installera webbservern

```bash
# Uppdatera alla paket
sudo yum update -y

# Installera webbservern Apache (heter httpd på Amazon Linux)
sudo yum install httpd -y
```

- `sudo` behövs för att ändra i systemet.
- `-y` svarar ja automatiskt på alla frågor.

![SSH-inloggning och installation av httpd](Bilder-v42/ssh.png)

### Starta webbservern

```bash
# Kolla status (först var den avstängd)
sudo systemctl status httpd

# Starta webbservern nu
sudo systemctl start httpd

# Starta webbservern automatiskt när servern startar om
sudo systemctl enable httpd

# Kolla status igen
sudo systemctl status httpd
```

Först stod det `inactive (dead)` och `disabled`. Efter `start` och `enable` stod det `active (running)` och `enabled`.

![httpd är igång och enabled](Bilder-v42/sudo-systemctl.png)

**Verifiering:** När jag surfade till `http://16.171.137.177` kom Apaches standardsida **"It works!"**. Då visste jag att httpd var igång och att port 80 var öppen.

![Apaches standardsida](Bilder-v42/IT-works.png)

---

## Delmoment 4: Novatrix-sidan

Webbservern läser sina filer från mappen `/var/www/html`. Filen `index.html` visas automatiskt när man surfar till IP-adressen.

Jag skapade filen med nano:

```bash
sudo nano /var/www/html/index.html
```

- `sudo` behövs eftersom mappen ägs av root.
- Spara i nano: `Ctrl+O`, `Enter`, sen `Ctrl+X` för att stänga.

Det här är koden (samma fil finns i repot som `V42/index.html`):

```html
<!DOCTYPE html>
<html lang="sv">
<head>
  <meta charset="utf-8">
  <title>Novatrix AB</title>
  <style>
    body { font-family: Verdana, sans-serif; max-width: 600px; margin: 60px auto; padding: 0 20px; background: #FFF8D6; color: #261C33; }
    h1 { color: #5B3FA0; }
  </style>
</head>
<body>
  <h1>Novatrix AB</h1>
  <p>Vi är Novatrix kundtjänst. Skicka ett ärende till oss, så hjälper vi dig.</p>
  <p>Sidan körs på en server i AWS (EC2) i Stockholm.</p>
</body>
</html>
```

- `<meta charset="utf-8">` gör att å, ä och ö visas rätt.
- `<style>` ger sidan färger och en lagom bred textspalt.

Jag behövde inte starta om httpd. Webbservern läser filen på nytt varje gång någon besöker sidan.

---

## Delmoment 5: Verifiering

Jag surfade till `http://16.171.137.177` och Novatrix-sidan visades.

![Novatrix-sidan på den publika IP-adressen](Bilder-v42/var-www-html.png)

Sammanfattning av hur jag verifierade varje delmoment:

| Delmoment | Hur jag kollade | Resultat |
|---|---|---|
| 1. GitHub-repo | `git status` och GitHub i webbläsaren | Alla filer finns, ingen nyckel |
| 2. EC2-instans | EC2-konsolen | Running, 3/3 checks passed |
| 3. Webbserver | `sudo systemctl status httpd` | `active (running)` |
| 4. Novatrix-sidan | `http://16.171.137.177` i webbläsaren | Sidan visas |
| 6. Budget | AWS Budgets | Status OK, mejladresser verifierade |

Man kan också kontrollera sidan direkt från servern med `curl localhost`. Då skrivs HTML-koden ut i terminalen.

---

## Delmoment 6: Budget och kostnadskontroll

Jag satte upp en månadsbudget i **AWS Budgets**.

| Inställning | Värde |
|---|---|
| Namn | `My Monthly Cost Budget` |
| Belopp | 10 USD per månad |
| Larm 1 | Faktisk kostnad över 85 % |
| Larm 2 | Faktisk kostnad över 100 % |
| Larm 3 | Prognostiserad kostnad över 100 % |
| Mottagare | Min skolmejl och min privata mejl |

- **Faktisk kostnad** är vad jag redan har betalat för.
- **Prognostiserad kostnad** är vad AWS tror att månaden kommer kosta. Det larmet varnar **innan** pengarna är slut.
- Båda mejladresserna är **verifierade**. Annars kommer inga larm fram.

![Budgeten i AWS Budgets](Bilder-v42/Budgets.png)

![Verifierade mejladresser och de tre larmen](Bilder-v42/Verifaction-mail.png)

---

## Säkerhet

- **MFA** är aktiverat på root-kontot.
- **SSH-nyckeln** ligger bara på min dator, i mappen `.ssh`. Den stoppas från repot av `.gitignore`.
- **Port 22** är bara öppen för min IP-adress.
- **Port 80** är öppen för alla, eftersom webbsidan ska kunna besökas.
- Sidan använder **http**, inte https. Det finns inget certifikat än.

## Städning

- Instansen kostar så länge den körs. När jag inte jobbar **stoppar** jag den (Stop, inte Terminate), eftersom vi bygger vidare på den nästa vecka.
- Den publika IP-adressen **byts** när instansen stoppas och startas igen. Då måste jag använda den nya adressen.
- Om jag byter nätverk måste jag uppdatera SSH-regeln till min nya IP-adress.
