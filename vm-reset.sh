#!/bin/sh
# NOTE!!!!
# this script should be run via sudo
#
# 1) Before starting, build a centos7 VM or download a cloud image for centos7
#    and then save the base qcow2 file.  See BASE below.
#
# 2) Using virt-manager define a number of VMs (e.g. 3 VMs if that's what you
#    need).  You MUST ensure that the libvirt disk name matches the hostname,
#    e.g. host-01 uses host-01.qcow2.  This should be the default behaviour.
#
# 3) You don't need to install the OS multiple times.  Either build once if you
#    are need to customize the OS, or just use the cloud image.
#
# 4) ensure your dynamic range for libvirt does not overlap with your IPs.  On
#    a workstation or laptop, you can run :  virsh net-edit default
#    and change the range for the IPs allocated to guests.  e.g. I use:
#
#     <range start='192.168.122.101' end='192.168.122.254'/>
#
#    Note: on fedora 23 it seems 192.168.124.x/24 was used, but this may vary
#          based on your installation.
#
#    This is to allow for static IPs on the guests.
#
# 5) Once you have your guests defined, also define them in the "guests"
#    associative array (REQUIRES BASH version 4!!!).
#
# 6) Edit the script being called in chroot (see "content_update" below)
#    and add your desired SSH pubkeys for your guests.
#
# This script will reset your guests to a vanilla state.
#
# determine the prefix for the libvirt network
net_prefix=$(virsh net-dumpxml default | grep range | awk -F\' '{ print $2 }' | awk -F. '{ print $1"."$2"."$3 }')
# this needs to exist in /var/lib/libvirt/images/
BASE=base.qcow2

declare -A guests
# The values are the 4th octet for the guests
guests=(
   ["host-01"]="81"
   ["host-02"]="82"
   )

echo "====== ensure in /etc/hosts"
for host in "${!guests[@]}" ; do
    echo "$net_prefix"."${guests["$host"]}" $host
done

function do_in_chroot {

if [ ! -d $1/tmp ]; then
  mkdir $1/tmp
fi

cat > $1/tmp/do_in_chroot.sh <<EOS
#!/bin/sh


function content_update {
    name=\$1
    octet=\$(cat /tmp/guest_octet)
    myip=${net_prefix}.\$octet

    cat > /etc/sysconfig/network-scripts/ifcfg-ens3 <<EOF
DEVICE="ens3"
BOOTPROTO="static"
ONBOOT="yes"
TYPE="Ethernet"
NAME="ens3"
DEVICE="ens3"
IPADDR="\$myip"
NETMASK="255.255.255.0"
GATEWAY="${net_prefix}.1"
DNS1="${net_prefix}.1"
EOF
   echo \$name > /etc/hostname
   echo GATEWAY=${net_prefix}.1 >> /etc/sysconfig/network
   echo SELINUX=permissive > /etc/sysconfig/selinux
   echo SELINUXTYPE=targeted >> /etc/sysconfig/selinux
   mkdir /root/.ssh/
   echo ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDSMXv+U2UAtg/m0lr8C6LbTT4GzXIAlOMSXZfu0BK+S2jMXHPxGdvYgvEDRDythwhMMIjS+zOpTZBsFXMqnZLWZomRn++7trHkxwjG2LuFZEUhUBCdXybb6KYoRT8CB1Nwa0wY+NB7mJrQDYZZcPGZHmpzPwE0S7C9I4qzaZWRyzFvmZp99e/6COmemQn2uizrPeb8jOIzseFeMyw6Ejp3NfZvNgG8WJUJsNw1QgMy59+/T9gGIkByJyHNPSVoMNEnPT0Uk4kt6juQ9o2ObhXPUQw/TCDIRD/kX+UTHONtgU7BJDE8Qaeq0H/9GCRMMsxtn6rDreLp3YFP0jQKP2Mp smalleni@smalleni_lap> /root/.ssh/authorized_keys
   chmod 700 /root/.ssh
   chmod 600 /root/.ssh/authorized_keys
}

content_update \$1

EOS
chmod 755 $1/tmp/do_in_chroot.sh
echo ============================
cat $1/tmp/do_in_chroot.sh
echo ============================

}

function rebuild {
    rm -f $1.qcow2
    # create the overlay
    qemu-img create -b `pwd`/$BASE -f qcow2 $1.qcow2

    # create dir to mount the overlay and update configs
    mkdir /mnt-tmp

    # mount the overlay
    guestmount -a $1.qcow2 -i --rw /mnt-tmp

    # create the script in /mnt-tmp/tmp/do_in_chroot.sh
    do_in_chroot /mnt-tmp

    # add all hosts to /etc/hosts in the guest
    for host in "${!guests[@]}" ; do
        echo "$net_prefix"."${guests["$host"]}" $host >> /mnt-tmp/etc/hosts
    done

    # store the 4th octet in chroot.  This is a hack
    echo "${guests["$1"]}" >> /mnt-tmp/tmp/guest_octet

    # now call the generated script in the chroot
    chroot /mnt-tmp /tmp/do_in_chroot.sh $1

    umount /mnt-tmp
    rmdir /mnt-tmp
}

cd /var/lib/libvirt/images/

for h in "${!guests[@]}" ; do
  virsh destroy $h
  rebuild $h
done

virsh net-destroy default
virsh net-start default

for h in "${!guests[@]}" ; do
  virsh start $h
done

