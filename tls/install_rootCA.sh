#!/bin/bash
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Copyright Clairvoyant 2015

# Function to discover basic OS details.
discover_os () {
  if command -v lsb_release >/dev/null; then
    # CentOS, Ubuntu
    OS=`lsb_release -is`
    # 7.2.1511, 14.04
    OSVER=`lsb_release -rs`
    # 7, 14
    OSREL=`echo $OSVER | awk -F. '{print $1}'`
    # trusty, wheezy, Final
    OSNAME=`lsb_release -cs`
  else
    if [ -f /etc/redhat-release ]; then
      if [ -f /etc/centos-release ]; then
        OS=CentOS
      else
        OS=RedHatEnterpriseServer
      fi
      OSVER=`rpm -qf /etc/redhat-release --qf="%{VERSION}.%{RELEASE}\n"`
      OSREL=`rpm -qf /etc/redhat-release --qf="%{VERSION}\n" | awk -F. '{print $1}'`
    fi
  fi
}

echo "********************************************************************************"
echo "*** $(basename $0)"
echo "********************************************************************************"
# Check to see if we are on a supported OS.
discover_os
if [ "$OS" != RedHatEnterpriseServer -a "$OS" != CentOS ]; then
#if [ "$OS" != RedHatEnterpriseServer -a "$OS" != CentOS -a "$OS" != Debian -a "$OS" != Ubuntu ]; then
  echo "ERROR: Unsupported OS."
  exit 3
fi

echo "Installing TLS root certificates..."
if [ -f /etc/profile.d/jdk.sh ]; then
  . /etc/profile.d/jdk.sh
elif [ -f /etc/profile.d/java.sh ]; then
  . /etc/profile.d/java.sh
fi

if [ -z "${JAVA_HOME}" ]; then echo "ERROR: \$JAVA_HOME is not set."; exit 10; fi

if [ ! -f ${JAVA_HOME}/jre/lib/security/jssecacerts ]; then
  /bin/cp -p ${JAVA_HOME}/jre/lib/security/cacerts ${JAVA_HOME}/jre/lib/security/jssecacerts
fi
keytool -importcert -file /opt/cloudera/security/CAcerts/ca.cert.pem -alias CAcert -keystore ${JAVA_HOME}/jre/lib/security/jssecacerts -storepass changeit -noprompt -trustcacerts
keytool -importcert -file /opt/cloudera/security/CAcerts/intermediate.cert.pem -alias CAcertint -keystore ${JAVA_HOME}/jre/lib/security/jssecacerts -storepass changeit -noprompt -trustcacerts

if [ "$OS" == RedHatEnterpriseServer -o "$OS" == CentOS ]; then
  if [ "$OS" == RedHatEnterpriseServer ]; then
    subscription-manager repos --enable=rhel-${OSREL}-server-optional-rpms
  fi
  if ! rpm -q openssl-perl; then yum -y -e1 -d1 install openssl-perl; fi
  c_rehash /opt/cloudera/security/CAcerts/

  if [ -d /etc/pki/ca-trust/source/anchors/ ]; then
    # Lets not enable dynamic certs if the customer has not done it themselves.
    #if [ "$OSREL" == 6 ]; then
    #  update-ca-trust check | grep -q DISABLED && update-ca-trust enable
    #fi
    cp -p /opt/cloudera/security/CAcerts/*.pem /etc/pki/ca-trust/source/anchors/
    update-ca-trust extract
  fi
elif [ "$OS" == Debian -o "$OS" == Ubuntu ]; then
  :
fi

