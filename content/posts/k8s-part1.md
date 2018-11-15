+++
title = "K8s Part1 - Setting up machines"
date = 2018-11-14T10:51:07+01:00
draft = true
tags = ["kubernetes" , "kvm" , "qemu" , "vm" , "centos"]
categories = []
+++


# What will be covered

* Kvm installation and configuration on a CentOS 7 server
* Vm creation with virt-install
* Configuration of a base VM to be a k8s node
* Cloning the base VM to create many nodes


# Usefull ressources links

* [How to install KVM on CentOS 7 / RHEL 7 Headless Server](https://www.cyberciti.biz/faq/how-to-install-kvm-on-centos-7-rhel-7-headless-server/)
* [How to clone existing KVM virtual machine images on Linux](https://www.cyberciti.biz/faq/how-to-clone-existing-kvm-virtual-machine-images-on-linux/)


# Prepare the server

Our host server is a CentOS 7 server and it has many cpu and plenty of ram.

## Install kvm

```
yum install qemu-kvm libvirt libvirt-python libguestfs-tools virt-install
```

## Start the libvirtd service:

```
systemctl enable libvirtd
systemctl start libvirtd
```


## Configure bridged networking

We will setup a network bridge on the server, like that all our VMs will be available on our LAN.


Update the nic config `/etc/sysconfig/network-scripts/ifcfg-enp5s0f1` adding the line :

```
BRIDGE=br0
```

Edit `/etc/sysconfig/network-scripts/ifcfg-br0` and add:

```
DEVICE="br0"
# I am getting ip from DHCP server #
BOOTPROTO="dhcp"
IPV6INIT="yes"
IPV6_AUTOCONF="yes"
ONBOOT="yes"
TYPE="Bridge"
DELAY="0"
```


Restart the networking service or reboot :
```
systemctl restart NetworkManager
```


Verify what we have done with brctl command :
```
brctl show
```



# Create our first VM

We will create a CentOS 7 VM, that will be our k8s base image.

## First download and check iso



```
cd /var/lib/libvirt/boot/
wget https://mirrors.edge.kernel.org/centos/7.5.1804/isos/x86_64/CentOS-7-x86_64-Minimal-1804.iso
wget https://mirrors.edge.kernel.org/centos/7.5.1804/isos/x86_64/sha1sum.txt
sha256sum -c sha256sum.txt
```


## Create the VM

Our base node image will have :

* 1 vcpu
* 4 Gb ram
* 40 Gb disk space
* 1 nic

```
virt-install \
--virt-type=kvm \
--name centos7-k8s-base-1vcpu-4Gram \
--ram 4096 \
--vcpus=1 \
--os-variant=centos7.0 \
--cdrom=/var/lib/libvirt/boot/CentOS-7-x86_64-Minimal-1804.iso' \
--network=bridge=br0,model=virtio \
--graphics vnc \
--disk path=/var/lib/libvirt/images/centos7-k8s-base-1vcpu-4Gram.qcow2,size=40,bus=virtio,format=qcow2'
```

Now, you need to configure vnc, so from another terminal type :  

```
virsh dumpxml centos7 | grep vnc

<graphics type='vnc' port='5901' autoport='yes' listen='127.0.0.1'>
```

Note down the port value : `5901`.

You need to use an SSH client to setup tunnel and a VNC client to access the remote vnc server.

Type the following SSH port forwarding command from your workstation :
```
ssh user@my-server -L 5901:127.0.0.1:5901
```

Once you have ssh tunnel established, you can point your VNC client at your own local address (127.0.0.1)  and port 5901.

Then you just have to follow instruction on screen to install CentOS in the VM.

##### _Remarks_

Enable networking and set manual ip if you want :

* ipv4 : 192.168.1.170
* mask : 255.255.255.0
* gateway : 192.168.1.101
* dns : 192.168.1.103


For disk allocation create :

* __/boot__ of 2GB as ext2
* __/__ all left space (~38GB) as ext4 in lvm
* __swap__ no swap (k8s do not want swap)

Do not create default user.

Just set root password.



# Prepare our VM to be a k8s node



## Update the system

```
yum update
```

## Install some usefull package you need

```
yum install vim net-tools
```

## Stop and disable firewall

```
systemctl stop firewalld
systemctl disable firewalld
```

## Enable ip forwarding

```
echo -e "\n# Ip forwarding \nnet.ipv4.ip_forward = 1" >> /usr/lib/sysctl.d/50-default.conf
/sbin/sysctl -p
```


# Create ansible-user

User creation :
```
groupadd --gid 30000 ansible-user
useradd  --uid 30000 --gid 30000 --create-home --comment "Compte pour Ansible" ansible-user
```

Ssh keys :

```
mkdir ~ansible-user/.ssh
curl -s http://laptop:8000/ansible.pub -o ~ansible-user/.ssh/authorized_keys
chmod 600 ~ansible-user/.ssh/authorized_keys
chmod 700 ~ansible-user/.ssh
chown -R ansible-user:ansible-user ~ansible-user/.ssh
```

Sudo access :

```
echo "ansible-user    ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers.d/ansible
chmod 600 /etc/sudoers.d/ansibl
```

# Clone base VM to create nodes VMs

Set some env variable to simplify :

```
BASE_NAME=centos7-k8s-base-1vcpu-4Gram
BASE_IP=192.168.1.170
NEW_NAME=k8s-node171
NEW_IP=192.168.1.171
```

Shutdown or suspend the base VM :

```
virsh  shutdown ${BASE_NAME}
```

Clone  :

```

virt-clone --original ${BASE_NAME} \
           --name ${NEW_NAME} \
           --file /home/vm_k8s/${NEW_NAME}.qcow2
```

Reset some settings and keep other :

```
virt-sysprep -d ${NEW_NAME} \
        --hostname ${NEW_NAME} \
        --enable user-account,ssh-hostkeys,net-hostname,net-hwaddr,machine-id \
        --keep-user-accounts ansible-user \
        --keep-user-accounts root
```

Start the new VM :

```
virsh start ${NEW_NAME}
```

Update some settings in the new node :

```
ssh root@192.168.1.170 -o StrictHostKeyChecking=no -o "UserKnownHostsFile /dev/null" "hostnamectl set-hostname ${NEW_NAME}"
ssh root@192.168.1.170 -o StrictHostKeyChecking=no -o "UserKnownHostsFile /dev/null" sed -i "s/${BASE_IP}/${NEW_IP}/" /etc/sysconfig/network-scripts/ifcfg-eth0
ssh root@192.168.1.170 -o StrictHostKeyChecking=no -o "UserKnownHostsFile /dev/null" reboot
```

You have to redo the above part as many times as you want more node.

Let's do this to have a total a 5 nodes as following :

|  NEW_NAME |    NEW_IP   |
|:---------:|:-----------:|
|k8s-node171|192.168.1.171|
|k8s-node172|192.168.1.172|
|k8s-node173|192.168.1.173|
|k8s-node174|192.168.1.174|
|k8s-node175|192.168.1.175|


Now we have 5 nodes ready to be our new test lab k8s cluster.
