# create-db   = Build user and DB, as well as grant user permissions
# sync-files  = Commit & push up anything left over on the server, and pull it down locally

# . okcommerce.cfg
. modx.cfg

declare create_db sync_files
while [ $# -gt 0 ] ; do
  case "$1" in
    -create-db)   create_db=1 ; shift ;;
    -sync-files) sync_files=1 ; shift ;;
    -*) echo "bad option '$1'" ; exit 1 ;;
  esac
done

[ ! -z "$create_db" ] && echo "r on"
[ ! -z "$sync_files" ] && echo "v on"

echo "$(tput setaf 2)SSHing into the server....$(tput sgr0)"
ssh -t -t $sshuser@$sshaddress<<EOF
  cd $sshdir
  rm mysqldump.sql
  git status
  git add --all
  git commit -m 'auto commit by script'
  git push origin $gitbranch
  mysqldump -u $sshdbuser -p$sshdbpassword $sshdbname > mysqldump.sql
  exit
EOF

echo "$(tput setaf 2)CDing to $localdir...$(tput sgr0)"
cd $localdir
echo "$(tput setaf 2)Pulling in any auto commits...$(tput sgr0)"
git pull origin $gitbranch
echo "$(tput setaf 2)SCPing mysql dump file from server...$(tput sgr0)"
scp $sshuser@$sshaddress:$sshdir/mysqldump.sql ./

if [ ! -z "$create_db" ]
  then
  echo "$(tput setaf 2)Building database/user, and granting permission...$(tput sgr0)"
  if [ $localrootpassword ]
    then
    mysql -u $localrootuser -p$localrootpassword -e "CREATE DATABASE $sshdbname;";
    mysql -u $localrootuser -p$localrootpassword -e "CREATE USER '$sshdbuser'@'localhost' IDENTIFIED BY '$sshdbpassword';";
    mysql -u $localrootuser -p$localrootpassword -e "GRANT ALL PRIVILEGES ON $sshdbname.* TO '$sshdbuser'@'localhost';";
    mysql -u $localrootuser -p$localrootpassword -e "FLUSH PRIVILEGES;";
  else
    mysql -u $localrootuser -e "CREATE DATABASE $sshdbname;";
    mysql -u $localrootuser -e "CREATE USER '$sshdbuser'@'localhost' IDENTIFIED BY '$sshdbpassword';";
    mysql -u $localrootuser -e "GRANT ALL PRIVILEGES ON $sshdbname.* TO '$sshdbuser'@'localhost';";
    mysql -u $localrootuser -e "FLUSH PRIVILEGES;";
  fi
fi

echo "$(tput setaf 2)Restoring mysql database from dump file...$(tput sgr0)"
mysql -u $sshdbuser -p$sshdbpassword $sshdbname < mysqldump.sql
echo "$(tput setaf 2)Turning off friendly urls...$(tput sgr0)"
mysql -u $sshdbuser -p$sshdbpassword <<EOF
  use $sshdbname;
  update modx_system_settings s set s.value = 0 where s.key = 'friendly_urls';
EOF
echo "$(tput setaf 2)DONE!$(tput sgr0)"
echo "$(tput setaf 2)*****************************$(tput sgr0)"
echo "$(tput setaf 2)If this is your initial setup, navigate to /setup and follow the instructions there; this will set up your config options$(tput sgr0)"
echo "$(tput setaf 2)You may need to add the /setup dir if it got doesn't exist$(tput sgr0)"
