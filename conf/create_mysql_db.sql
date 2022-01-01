-- create database
-- for cloudera manager
create database scm DEFAULT CHARACTER SET utf8;
-- for Reports Manager
create database rman DEFAULT CHARACTER SET utf8;
-- for Hive Metastore Server
create database metastore DEFAULT CHARACTER SET utf8;
-- for oozie
create database oozie DEFAULT CHARACTER SET utf8;
-- for hue
create database hue DEFAULT CHARACTER SET utf8;
-- for ranger
create database ranger DEFAULT CHARACTER SET utf8;
 
-- create corresponding user
CREATE USER 'scm'@'localhost' IDENTIFIED BY 'cloudera';
CREATE USER 'rman'@'localhost' IDENTIFIED BY 'cloudera';
CREATE USER 'hive'@'localhost' IDENTIFIED BY 'cloudera';
CREATE USER 'oozie'@'localhost' IDENTIFIED BY 'cloudera';
CREATE USER 'hue'@'localhost' IDENTIFIED BY 'cloudera';
CREATE USER 'ranger'@'localhost' IDENTIFIED BY 'cloudera';
 
-- grant permissions
grant all on scm.* TO 'scm'@'%' IDENTIFIED BY 'cloudera';
grant all on rman.* TO 'rman'@'%' IDENTIFIED BY 'cloudera';
grant all on metastore.* TO 'hive'@'%' IDENTIFIED BY 'cloudera';
grant all on oozie.* TO 'oozie'@'%' IDENTIFIED BY 'cloudera';
grant all on hue.* TO 'hue'@'%' IDENTIFIED BY 'cloudera';
grant all on ranger.* TO 'ranger'@'%' IDENTIFIED BY 'cloudera';
flush privileges;