#!/bin/bash
# user-data.sh (V42, VG)
# Det här skriptet körs av SERVERN själv, en gång, vid första starten.
# Det körs som root, så sudo behövs inte.
# Loggen hamnar på servern i /var/log/cloud-init-output.log

# -e: stoppa direkt om ett kommando misslyckas
# -x: skriv ut varje kommando i loggen, så det är lätt att felsöka
set -ex

# 1. Uppdatera paketen och installera webbservern Apache (httpd)
yum update -y
yum install -y httpd

# 2. Starta httpd nu (--now) och automatiskt efter omstart (enable)
systemctl enable --now httpd

# 3. Hämta Novatrix-sidan från mitt repo på GitHub
#    -f  avbryt om sidan inte finns (sparar inte en felsida)
#    -sS tyst, men visa fel
#    -L  följ vidarekopplingar
#    -o  spara som index.html i webbmappen
curl -fsSL https://raw.githubusercontent.com/02simfat/AWS-MOV25/main/V42/index.html -o /var/www/html/index.html
