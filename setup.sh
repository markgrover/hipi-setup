#!/bin/bash
# Run this code on one of the nodes of your hadoop cluster. Pre-requisite, a cluster with a recent version of Hadoop, installed as CDH parcels

# This code downloads the source tarball for hipi and unbundles it
cd ~
mkdir hipi-src
cd hipi-src
wget http://hipi.cs.virginia.edu/downloads/hipi-src.tar.bz2
bunzip2 hipi-src.tar.bz2
tar -xvf hipi-src.tar

# This code sets up the necessary dependencies for building hipi. These include JDK6 (it cannot be built with JDK7) and ant
cd /tmp
wget http://mirror.infra.cloudera.com/toolchain/el6/RPMS/x86_64/sun-jdk-64bit-1.7.0.67-1.7.0.67_0-1.x86_64.rpm
wget http://mirror.infra.cloudera.com/toolchain/el6/RPMS/noarch/apache-ant-1.8.2-1.8.2-2.noarch.rpm
wget http://mirror.infra.cloudera.com/toolchain/el6/RPMS/x86_64/sun-jdk-64bit-1.6.0.31-1.6.0.31.x86_64.rpm
sudo yum install apache-ant*.rpm sun-jdk-64bit*.rpm
cd -

export PATH=$PATH:/opt/toolchain/apache-ant-1.8.2/bin
export PATH=$PATH:/opt/toolchain/sun-jdk-64bit-1.6.0.31/bin

# You can download a jar directly from the release of hipi if you are not into building it.
# But this jar is missing many tools etc. so it's recommended to build it.
#wget http://hipi.cs.virginia.edu/downloads/hipi-0.1.0.jar

# This code assumes that you already have a CDH cluster with parcels set up. The parcels are used
# by the hipi buidl to link against the hadoop client jars
PARCELS_ROOT=/opt/cloudera/parcels
. /opt/cloudera/parcels/CDH/meta/cdh_env.sh
export HADOOP_HOME=$CDH_HADOOP_HOME
export HADOOP_VERSION=$(hadoop version | head -1 | sed -e 's/Hadoop //g')
export HADOOP_CLASSPATH=${CDH_HADOOP_HOME}/client-0.20/hadoop-common.jar:${CDH_HADOOP_HOME}/client-0.20/hadoop-core.jar
ant -Dhadoop.home=${HADOOP_HOME} -Dhadoop.version=${HADOOP_VERSION} -Dhadoop.classpath=${HADOOP_CLASSPATH}

# This code is prepping up for running some analysis on some pictures. Here we put a link to 3 pictures of Obama
# in a file called pics.txt
rm /tmp/pics.txt
echo "http://blogs.reuters.com/great-debate/files/2014/03/obama.jpg" >> ~/pics.txt
echo "http://a.abcnews.com/images/US/AP_OBAMA_150102_DG_16x9_992.jpg" >> ~/pics.txt
echo "http://media3.s-nbcnews.com/i/newscms/2014_22/471411/140528-obama-west-point-mn-1155_a321bf5f75359e045403b1c5436f31aa.JPG" >> /tmp/pics.txt

# Now we are copying over the txt file containing image names to HDFS so the subsequent MR job can use it
sudo -u hdfs hadoop fs -mkdir /pics
sudo -u hdfs hadoop fs -put /tmp/pics.txt /pics

# Prepping the output directory for the MR job
sudo -u hdfs hadoop fs -mkdir /hibs
sudo -u hdfs hadoop fs -rm -r /hibs/obama.hib

# This is more of a hack. The MR job is being run as hdfs user (even though that's a bad practice, this is proof-of-concept afterall). However, the HDFS user can't see the jar in the regular home directory of the root user. So, the jar that's going to run the MR job is first copied to /tmp on the local machine where everyone has read access.
cp ~/hipi-src/examples/downloader.jar /tmp
# This MR job downloads the images and creates a special archive with them, called a hib file
sudo -u hdfs hadoop jar /tmp/downloader.jar /pics/pics.txt /hibs/obama.hib 4
cp ~/hipi-src/firstprog/firstprog.jar /tmp

sudo -u hdfs hadoop fs -mkdir /results
sudo -u hdfs hadoop fs -rm -r /results/obama
# This job run the custom MR job for calculating the average color of all 3 images of Obama
sudo -u hdfs hadoop jar /tmp/firstprog.jar /hibs/obama.hib /results/obama

