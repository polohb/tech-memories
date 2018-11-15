+++
title = "K8s Part2 - Deploy Kubernetes"
date = 2018-11-14T16:20:42+01:00
draft = true
tags = ["kubernetes" , "kubespray" ]
categories = []
+++



# What will be covered

* Kubespray installation and configuration
* Cluster deployment
* Access the kubernetes dashboard with ACL


# Usefull ressources links

* [Installer Kubernetes avec Kubespray](https://blog.zwindler.fr/2017/12/05/installer-kubernetes-kubespray-ansible/?doing_wp_cron=1540473835.1111199855804443359375)
* [Kubespray : Getting started](https://github.com/kubernetes-incubator/kubespray/blob/master/docs/getting-started.md)
* [kubernetes dashboard : admin-user](https://github.com/kubernetes/dashboard/wiki/Creating-sample-user)



# Prepare environment

First you need python3 and virtual-env :

```
sudo aptitude install python3 python3-dev python3-pip python-virtualenv
```

Then we will create a virtualenv for ansible :

```
mkdir -p ~/CODE/VirtualEnv/py3/
cd ~/CODE/VirtualEnv/py3/
virtualenv -p python3 ansible-kubespray
```

 And load the virtualenv :
```
 . ~/CODE/VirtualEnv/py3/ansible-kubespray/bin/activate
 ```


# Get and configure kubespray

Clone kubespray from github :

```
mkdir -p ~/CODE/K8s
cd ~/CODE/K8s
git clone https://github.com/kubernetes-incubator/kubespray
cd kubespray
```

Install require dependencies :

```
pip install ansible==2.5.11
pip install -r requirements.txt
```

Copy inventory to make our own configuration :

```
cp -r inventory inventaire_kubernetes
```

Declare IP of future nodes :

```
declare -a IPS=(192.168.1.171 192.168.1.172 192.168.1.173 192.168.1.174 192.168.1.175)
CONFIG_FILE=inventaire_kubernetes/inventory.cfg python contrib/inventory_builder/inventory.py ${IPS[@]}
```


As we want :
 * 2 masters without containers
 * 3 workers

We  can manually edit the `inventaire_kubernetes/inventory.cfg`
to have the following content :

```
[all]
node1 	 ansible_host=192.168.1.171 ip=192.168.1.171
node2 	 ansible_host=192.168.1.172 ip=192.168.1.172
node3 	 ansible_host=192.168.1.173 ip=192.168.1.173
node4 	 ansible_host=192.168.1.174 ip=192.168.1.174
node5 	 ansible_host=192.168.1.175 ip=192.168.1.175

[kube-master]
node1
node2

[kube-node]
node3
node4
node5

[etcd]
node1
node2
node3

[k8s-cluster:children]
kube-node
kube-master

[calico-rr]

[vault]
node1
node2
node3
```


# Deploying the cluster


Deploy the cluster with the folling line :

```
ansible-playbook -i inventaire_kubernetes/inventory.cfg \
    cluster.yml \
    -e ansible_user=ansible-user \
    -b --become-user=root \
    -v --private-key=~/CODE/Tools/adminsys/ansible/keys/ansible
```

Go take a break, this is a very long task ~20 minutes.


# Check the cluster

If you want to run kubectl commands from your laptop,
get the kubeconfig from the one of the master :

```
scp root@192.168.1.171:~/.kube/config ~/.kube/config
```

Verify the cluster :

```
kubectl cluster-info
```


# Kubernetes dashboard


First we need to create a ServiceAccount and a ClusterRoleBinding.


Write an `admin-user.yaml` file with the following content :

```
---
# create a service account
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kube-system
---
# create cluster role binding
# vlusterTole cluster-admin should already exits
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kube-system
  ```

Then apply the file to the cluster :

```
kubectl apply -f admin-user.yaml
```

Now we need to find token we can use to log in :

```
kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep admin-user | awk '{print $1}')
```


It should print something like this :
```
Name:         admin-user-token-kvdg2
Namespace:    kube-system
Labels:       <none>
Annotations:  kubernetes.io/service-account.name: admin-user
              kubernetes.io/service-account.uid: ff1f1381-e8ba-11e8

Type:  kubernetes.io/service-account-token

Data
====
ca.crt:     1090 bytes
namespace:  11 bytes
token:      eyJhbGciOiJeyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc
```


Then run `kubectl proxy` and open the following link :

```
http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/#!/login
```

Now copy the token and paste it into the _Token_ field on log in screen and sign-in.
