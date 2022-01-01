#!/bin/bash
workdir=$(cd $(dirname $0); pwd)
echo "> Installing some tools"
yum install -y vim rng-tools rsync tmux git lrzsz tmux

echo "-- Configure user cloudera with passwordless"
useradd cloudera -d /home/cloudera -p cloudera
sudo usermod -aG wheel cloudera
cp /etc/sudoers /etc/sudoers.bkp
rm -rf /etc/sudoers
sed '/^#includedir.*/a cloudera ALL=(ALL) NOPASSWD: ALL' /etc/sudoers.bkp > /etc/sudoers
echo "-- Configure and optimize the OS"
echo never > /sys/kernel/mm/transparent_hugepage/enabled
echo never > /sys/kernel/mm/transparent_hugepage/defrag
echo "echo never > /sys/kernel/mm/transparent_hugepage/enabled" >> /etc/rc.d/rc.local
echo "echo never > /sys/kernel/mm/transparent_hugepage/defrag" >> /etc/rc.d/rc.local
# add tuned optimization https://www.cloudera.com/documentation/enterprise/6/6.2/topics/cdh_admin_performance.html
echo  "vm.swappiness = 1" >> /etc/sysctl.conf
sysctl vm.swappiness=1
timedatectl set-timezone "Asia/Shanghai"

echo "-- Install Java OpenJDK8 and other tools"
yum install -y java-1.8.0-openjdk-devel vim wget curl git bind-utils rng-tools
yum install -y epel-release
yum install -y python-pip

cp /usr/lib/systemd/system/rngd.service /etc/systemd/system/
systemctl daemon-reload
systemctl start rngd
systemctl enable rngd

# echo "-- Installing requirements for Stream Messaging Manager"
# yum install -y gcc-c++ make
# curl -sL https://rpm.nodesource.com/setup_14.x | sudo -E bash -
# yum install nodejs -y
# echo "-- use taobao npm registry "
# npm install forever -g --registry=https://registry.npm.taobao.org

echo "server 169.254.169.123 prefer iburst minpoll 4 maxpoll 4" >> /etc/chrony.conf
systemctl restart chronyd

sudo /etc/init.d/network restart

echo "-- set hostname to cloudera"
hostname cloudera
echo "`hostname -I` cloudera" >> /etc/hosts
# disable default repo
echo "127.0.0.1 archive.cloudera.com" >> /etc/hosts

systemctl disable firewalld
systemctl stop firewalld
service firewalld stop
setenforce 0
sed -i 's/SELINUX=.*/SELINUX=disabled/' /etc/selinux/config

echo  "Disabling IPv6"
echo "net.ipv6.conf.all.disable_ipv6 = 1
      net.ipv6.conf.default.disable_ipv6 = 1
      net.ipv6.conf.lo.disable_ipv6 = 1
      net.ipv6.conf.eth0.disable_ipv6 = 1" >> /etc/sysctl.conf
sysctl -p

echo "-- Install CM and MariaDB"

cd /
echo "-- use cm7.4.4 trial"
# wget https://archive.cloudera.com/cm7/7.4.4/redhat7/yum/cloudera-manager-trial.repo -P /etc/yum.repos.d/
cat - >/etc/yum.repos.d/cloudera-manager.repo <<EOF
[cloudera-manager]
name = Cloudera Manager 7.4.4
baseurl = http://10.32.2.18/cloudera/cm/cm7.4.4/
gpgcheck=0
EOF


echo "-- use ustc MariaDB yum repo"
# MariaDB 10.1
cat - >/etc/yum.repos.d/MariaDB.repo <<EOF
[mariadb]
name = MariaDB
baseurl = https://mirrors.ustc.edu.cn/mariadb/yum/10.4/centos7-amd64/
gpgkey=https://mirrors.ustc.edu.cn/mariadb/yum/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOF

yum clean all
rm -rf /var/cache/yum/
yum repolist

## CM
yum install -y cloudera-manager-agent cloudera-manager-daemons cloudera-manager-server

sed -i$(date +%s).bak 's/localhost/`hostname -f`' /etc/cloudera-scm-agent/config.ini

service cloudera-scm-agent restart

## MariaDB
yum install -y MariaDB-server MariaDB-client
cat $workdir/conf/mariadb.config > /etc/my.cnf

echo "--Enable and start MariaDB"
systemctl enable mariadb
systemctl start mariadb

echo "-- Install JDBC connector"
wget https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-5.1.46.tar.gz -P ~
tar zxf ~/mysql-connector-java-5.1.46.tar.gz -C ~
mkdir -p /usr/share/java/
cp ~/mysql-connector-java-5.1.46/mysql-connector-java-5.1.46-bin.jar /usr/share/java/mysql-connector-java.jar
rm -rf ~/mysql-connector-java-5.1.46*

echo "-- Create DBs required by CM"
mysql -u root < $workdir/conf/create_mysql_db.sql

echo "-- Secure MariaDB"
mysql -u root < $workdir/conf/secure_mariadb.sql

echo "-- Prepare CM database 'scm'"
/opt/cloudera/cm/schema/scm_prepare_database.sh mysql scm scm cloudera

echo "-- Enable passwordless root login via rsa key for cm api"
ssh-keygen -f ~/myRSAkey -t rsa -N ""
mkdir ~/.ssh
cat ~/myRSAkey.pub >> ~/.ssh/authorized_keys
chmod 400 ~/.ssh/authorized_keys
ssh-keyscan -H `hostname` >> ~/.ssh/known_hosts
systemctl restart sshd

echo "-- Start CM, it takes about 2 minutes to be ready"
systemctl start cloudera-scm-server

while [ ! `curl -s -X GET -u "admin:admin"  http://localhost:7180/api/version` ] ;
    do
    echo "waiting 10s for CM to come up..";
    sleep 10;
done

echo "-- Now CM is started and the next step is to automate using the CM API"

pip install --upgrade cm_client  -i https://pypi.douban.com/simple/

sed -i "s/YourHostname/`hostname -f`/g" $workdir/create_cluster.py

python $workdir/create_cluster.py $workdir/templates/base.json

sudo usermod cloudera -G hadoop
sudo -u hdfs hdfs dfs -mkdir /user/cloudera
sudo -u hdfs hdfs dfs -chown cloudera:hadoop /user/cloudera
sudo -u hdfs hdfs dfs -mkdir /user/admin
sudo -u hdfs hdfs dfs -chown admin:hadoop /user/admin
sudo -u hdfs hdfs dfs -chmod -R 0755 /tmp


echo "> reboot maybe needed"