+++
title = "Create chroot jail for ssh access"
date = 2018-11-09T23:51:32+01:00
draft = true
tags = ["server","linux","security"]
categories = []
+++

# Setup group and users

```
    groupadd jailusers
    adduser userjailed
    usermod -a -G jailusers userjailed
```

# Setup the jail directories

```
    mkdir -p /var/jail/{dev,etc,lib,usr,bin,lib64}
    mkdir -p /var/jail/usr/bin
    chown root.root /var/jail
```

You also need the /dev/null file:

```
    mknod -m 666 /var/jail/dev/null c 1 3
```

You need to fill up the etc directory with a few minimum files:

```
    cd /var/jail/etc
    cp /etc/ld.so.cache .
    cp /etc/ld.so.conf .
    cp /etc/nsswitch.conf .
    cp /etc/hosts .
```

Once this is done you need to figure out what commands you want accessible by your limited users.

In this example I only want the users to be able to get into bash and use the ls command. So you must copy the binaries to the jail.

```
    cd /var/jail/bin
    cp /bin/ls .
    cp /bin/bash .
```

Now that you've got all the binaries in place, you need to add the proper shared libraries. 
Use the following useful script called l2chroot which automatically finds the libraries and copies them to your chroot jail.

```
    cd /tmp
    wget -O l2chroot http://www.cyberciti.biz/files/lighttpd/l2chroot.txt
    chmod +x l2chroot
```

Edit the l2chroot file and change `BASE="/webroot"` to `BASE="/var/jail"`. 
This tells l2chroot where your jail is located so it copies everything to the right place. 
Now go ahead and run the command on the binaries you want.

```
    l2chroot /bin/ls
    l2chroot /bin/bash
```

# Configure SSHd to Chroot your users

To configure ChrootDirectory add the following to /etc/ssh/sshd_config:

```
    Match group jailusers
        ChrootDirectory /var/jail/
        X11Forwarding no
        AllowTcpForwarding no
```

Note that by default this disables X11Forwarding and does not allow port forwarding. 
If you want to enable one, you just need to change ‘no’ for ‘yes’.


