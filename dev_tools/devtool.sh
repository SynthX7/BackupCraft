read -rp "Version to remove: " r

rm -rf BackupCraft-v$r.tar.gz

tar -cvzf backupcraft.tar.gz bchub.sh
mkdir BackupCraft
mv backupcraft.tar.gz BackupCraft/
cp install.sh BackupCraft/

read -rp "Version to create: " v

tar -cvzf BackupCraft-v$v.tar.gz BackupCraft/
rm -rf BackupCraft

read -rp "Commit: " c
git add .
git commit -m "$c"
git push origin main
