tar -cvzf backupcraft.tar.gz bchub.sh
mkdir BackupCraft
mv backupcraft.tar.gz BackupCraft/
cp bchub.sh BackupCraft/

read -rp "Version (like 1.0.0):" v

tar -cvzf BackupCraft-v$v.tar.gz BackupCraft/
rm -rf BackupCraft
