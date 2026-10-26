#!/bin/bash
# user-data-s3.sh (V43, VG)
# Körs av servern själv, en gång, vid första starten. Den körs som root.
# Skillnad mot V42: sidan hämtas från S3 (mappen publicerat/) i stället för från GitHub.
# Servern får läsa S3 tack vare rollen novatrix-ec2-webb. Inga nycklar finns på servern.
# deploy.ps1 fyller i bucketnamn och region innan skriptet skickas till AWS.

# -e: stoppa vid första fel   -x: skriv varje kommando i loggen
set -ex

# Webbservern, samma som i V42
yum update -y
yum install -y httpd
systemctl enable --now httpd

# Hämta den publicerade sidan med rollens tillfälliga nycklar
aws s3 cp s3://BUCKETNAMN/publicerat/index.html /var/www/html/index.html --region REGION
