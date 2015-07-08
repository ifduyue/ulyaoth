#!/bin/bash
# Argument = -h (shows the help information)
# Argument = -l (lists all supported versions)
# Argument = -b (branch .i.e 3.7)
# Argument = -v (version .i.e 3.7.3)
# Created By: Sjir Bagmeijer - 2015/07/08
# Last Edit By: Sjir Bagmeijer - 2015/07/08
# https://community.ulyaoth.net

usage()
{
cat << EOF
usage: $0 options

OPTIONS:
   -h  Shows this help information
   -l  Show list of all supported versions
   -b  Choose to your HHVM branch.
   -v  Choose the HHVM version you wich to install.
EOF
exit 1
}

hhvm()
{
cd /home/ulyaoth
su ulyaoth -c "git clone -b HHVM-'"$hhvmbranchversion"' git://github.com/facebook/hhvm.git"
mv /home/ulyaoth/hhvm /home/ulyaoth/hhvm-$hhvmversion
cd /home/ulyaoth/hhvm-$hhvmversion
su ulyaoth -c "git checkout HHVM-'"$hhvmversion"'"
su ulyaoth -c "git submodule update --init --recursive"
cd /home/ulyaoth
su ulyaoth -c "tar cvf hhvm-'"$hhvmversion"'.tar.gz hhvm-'"$hhvmversion"'/"
mv /home/ulyaoth/hhvm-$hhvmversion.tar.gz /home/ulyaoth/rpmbuild/SOURCES/
} >> /var/log/build-ulyaoth-hhvm.log 2>&1

preparebuild()
{
cd /home/ulyaoth
su ulyaoth -c "rpmdev-setuptree"
cd /home/ulyaoth/rpmbuild/SPECS/

if [ "$hhvmbranchversion" == "3.3" ]
then
su ulyaoth -c "wget https://raw.githubusercontent.com/sbagmeijer/ulyaoth/master/Repository/ulyaoth-hhvm/SPECS/ulyaoth-hhvm-lts-3.3.spec"
elif [ "$hhvmbranchversion" == "3.6" ]
then
su ulyaoth -c "wget https://raw.githubusercontent.com/sbagmeijer/ulyaoth/master/Repository/ulyaoth-hhvm/SPECS/ulyaoth-hhvm-lts-3.6.spec"
elif [ "$hhvmbranchversion" == "3.7" ]
then
su ulyaoth -c "wget https://raw.githubusercontent.com/sbagmeijer/ulyaoth/master/Repository/ulyaoth-hhvm/SPECS/ulyaoth-hhvm.spec"
fi

installrequirements &
} >> /var/log/build-ulyaoth-hhvm.log 2>&1

installrequirements()
{
if grep -q -i "release 7" /etc/redhat-release
then
yum install -y  http://mirror.nsc.liu.se/fedora-epel/7/x86_64/e/epel-release-7-5.noarch.rpm
fi

if grep -q -i "release 22" /etc/fedora-release
then
dnf builddep -y /home/ulyaoth/rpmbuild/SPECS/ulyaoth-hhvm*.spec
else
yum-builddep -y /home/ulyaoth/rpmbuild/SPECS/ulyaoth-hhvm*.spec
fi

su ulyaoth -c "spectool /home/ulyaoth/rpmbuild/SPECS/ulyaoth-hhvm*.spec -g -R"
} >> /var/log/build-ulyaoth-hhvm.log 2>&1

build()
{
su ulyaoth -c "QA_SKIP_BUILD_ROOT=1 rpmbuild -bb /home/ulyaoth/rpmbuild/SPECS/ulyaoth-hhvm*.spec"
} >> /var/log/build-ulyaoth-hhvm.log 2>&1

clean()
{
cp /home/ulyaoth/rpmbuild/RPMS/x86_64/* /root/
rm -rf /home/ulyaoth/hhvm-$hhvmversion
rm -rf /home/ulyaoth/rpmbuild
rm -rf /root/build-ulyaoth-hhvm*.sh
cd /root
} >> /var/log/build-ulyaoth-hhvm.log 2>&1

availablehhvmversions()
{
cat <<EOF
Branch 3.7 versions supported:
* 3.7.3
* 3.7.2
* 3.7.1
* 3.7.0

Branch 3.6 versions supported: (LTS build)
* 3.6.5
* 3.6.4
* 3.6.3
* 3.6.2
* 3.6.1
* 3.6.0

Branch 3.3 versions supported: (LTS build)
* 3.3.7
* 3.3.6
* 3.3.5
* 3.3.4
* 3.3.3
* 3.3.2
* 3.3.1
* 3.3.0
EOF
exit 1
}

arraychecker() {
    local n=$#
    local value=${!n}
    for ((i=1;i < $#;i++)) {
        if [ "${!i}" == "${value}" ]; then
            echo "y"
            return 0
        fi
    }
    echo "n"
    return 1
}

hhvmbranchversion=
hhvmversion=
arch="$(uname -m)"
supportedbranches=('3.3' '3.6' '3.7')
supportedversions=('3.7.3' '3.7.2' '3.7.1' '3.7.0' '3.6.5' '3.6.4' '3.6.3' '3.6.2' '3.6.1' '3.6.0' '3.3.7' '3.3.6' '3.3.5' '3.3.4' '3.3.3' '3.3.2' '3.3.1' '3.3.0')

if [ "$arch" != "x86_64" ];
then
echo Sorry HHVM only supports a 64-bit platform.
exit 1
fi

while getopts ":h :l :b: :v:" opt; do
case $opt in
h)
  usage
;;
l)
  availablehhvmversions
;;
b)
  hhvmbranchversion=$OPTARG
;;
v)
  hhvmversion=$OPTARG
;;
\?)
  usage
;;
:)
  usage
;;
esac
done


if [ -z "$hhvmbranchversion" ];
then
  usage
elif [ -z "$hhvmversion" ]
then
  usage
elif [[ " ${supportedbranches[*]} " != *" $hhvmbranchversion "* ]]
then
  echo Currently only the following branches are supported: ${supportedbranches[*]}.
exit 1
elif [[ " ${supportedversions[*]} " != *" $hhvmversion "* ]]
then
  echo "Please run the script with the -l option to see a list of supported versions. (.i.e ulyaoth-hhvm.sh -l)"
exit 1
fi

# Create build user
useradd ulyaoth &> /dev/null

echo "Step 1: Starting the HHVM Download process in background."
hhvm &
echo "Step 2: Downloading & installing all requirements for HHVM."
preparebuild &
echo "Waiting for Step 1 and Step 2 to finish before building. (This can take up to 30 minutes depending on your download speed)"
wait

echo "Step 3: Building the HHVM RPM. (This can take up to 1 hour or longer depending on your build machine)"
build
echo "Step 4: Cleaning your build environment."
clean

echo "Your RPM has been created and placed in your root directory."
exit