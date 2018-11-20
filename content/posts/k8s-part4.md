+++
title = "K8s Part4 - Storage with Rook.io"
date = 2018-11-16T15:20:33+01:00
draft = true
tags = ["kubernetes" , "rook.io" , ""]
categories = []
+++

# What will be covered

* Deploy a rook operator and cluster
* Example use of block storage type
* Example use of Shared File System type


# Usefull ressources links

* [Rook.io github](https://github.com/rook/rook)
* [Rook.io doc](https://rook.github.io/docs/rook/v0.8/)
* [Rook.io Ceph](https://rook.github.io/docs/rook/v0.8/ceph-quickstart.html#deploy-the-rook-operator)

# Prepare environment

## FlexVolume Configuration

On our installation the FlexVolume dir path is not the default one.

Note that we have `/var/lib/kubelet/volume-plugins`

When deploying the _rook-operator_ we will need to provide this path
by setting the environment variable `FLEXVOLUME_DIR_PATH`.


## Ceph Storage

We need to get the examples files :

```
cd ~/CODE/K8s
git clone https://github.com/rook/rook.git
cd rook
git checkout -b r0.8 remotes/origin/release-0.8
cd cluster/examples/kubernetes/ceph
```

### Deploy the Rook Operator

Edit the `operator.yaml` to provide our FlexVolume dir path :

```
...

- name: FLEXVOLUME_DIR_PATH
  value: "/var/lib/kubelet/volume-plugins"

...
```

Deploy the rook operator :

```
kubectl create -f operator.yaml

```
We can verify some pods are in the `Running` state :

```
kubectl -n rook-ceph-system get pod
```

```
NAME                                  READY   STATUS    RESTARTS   AGE
rook-ceph-agent-979rw                 1/1     Running   0          5m42s
rook-ceph-agent-n2zzv                 1/1     Running   0          5m42s
rook-ceph-agent-wmkxj                 1/1     Running   0          5m42s
rook-ceph-operator-6984955d8f-9m68g   1/1     Running   0          6m14s
rook-discover-6m87d                   1/1     Running   0          5m42s
rook-discover-d6s2k                   1/1     Running   0          5m42s
rook-discover-lhlff                   1/1     Running   0          5m42s

```



### Create a Rook Cluster

```
kubectl create -f cluster.yaml
```

We can verify some pods are in the `Running` state :
```
kubectl -n rook-ceph get pod
```

```
NAME                                  READY   STATUS      RESTARTS   AGE
rook-ceph-mgr-a-5f6dd98574-lqxrz      1/1     Running     0          3m20s
rook-ceph-mon0-5jkjw                  1/1     Running     0          5m10s
rook-ceph-mon1-nzwxc                  1/1     Running     0          4m39s
rook-ceph-mon2-wz4rc                  1/1     Running     0          4m2s
rook-ceph-osd-id-0-75c4b9b48b-dg9kp   1/1     Running     0          2m17s
rook-ceph-osd-id-1-75f8d866dd-xz4bf   1/1     Running     0          2m2s
rook-ceph-osd-id-2-c74c5f687-lzsmf    1/1     Running     0          2m11s
rook-ceph-osd-prepare-node3-dkk6j     0/1     Completed   0          3m7s
rook-ceph-osd-prepare-node4-v88rx     0/1     Completed   0          3m7s
rook-ceph-osd-prepare-node5-gc4qp     0/1     Completed   0          3m1s
```


### View the dashboard

Like we have already installed and configured an Ingress Traefik we can easly wie the ceph dashboard :

Create a `ceph-ingress.yaml` file :

```
---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: ceph-dashboard
  namespace: rook-ceph
spec:
  rules:
  - host: ceph-ui.k8s.pau.int.com
    http:
      paths:
      - path: /
        backend:
          serviceName: rook-ceph-mgr-dashboard
          servicePort: 7000
  # tls:
  #  - secretName: traefik-ui-tls-cert
```

Apply the file :

```
kubectl apply -f ceph-ingress.yaml
```


Go to your new url : http://ceph-ui.k8s.pau.int.com


## Block Storage

### Provision storage

Before Rook can start provisioning storage,
a StorageClass and its storage pool need to be created.

Edit `storageclass.yaml` :

```
apiVersion: ceph.rook.io/v1beta1
kind: Pool
metadata:
  name: replicapool
  namespace: rook-ceph
spec:
  replicated:
    size: 3
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
   name: rook-ceph-block
provisioner: ceph.rook.io/block
parameters:
  pool: replicapool
  clusterNamespace: rook-ceph
```
```
kubectl apply -f storageclass.yaml
```


### Consume storage

Then we can consume the storage with the "Wordpress sample"
in the `cluster/examples/kubernete` folder :


Edit `wordpress.yaml` to have something like the following :

```
apiVersion: v1
kind: Service
metadata:
  name: wordpress
  labels:
    app: wordpress
spec:
  ports:
  - port: 80
  selector:
    app: wordpress
    tier: frontend
# we use Ingress so service is not a LoadBalancer type
#  type: LoadBalancer
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: wp-pv-claim
  labels:
    app: wordpress
spec:
  storageClassName: rook-ceph-block
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
---
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: wordpress
  labels:
    app: wordpress
spec:
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: wordpress
        tier: frontend
    spec:
      containers:
      - image: wordpress:4.6.1-apache
        name: wordpress
        env:
        - name: WORDPRESS_DB_HOST
          value: wordpress-mysql
        - name: WORDPRESS_DB_PASSWORD
          value: changeme
        ports:
        - containerPort: 80
          name: wordpress
        volumeMounts:
        - name: wordpress-persistent-storage
          mountPath: /var/www/html
      volumes:
      - name: wordpress-persistent-storage
        persistentVolumeClaim:
          claimName: wp-pv-claim
---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: wordpress-web-ui
spec:
  rules:
  - host: wp.mydomain.com
    http:
      paths:
      - path: /
        backend:
          serviceName: wordpress
          servicePort: 80
```

Then apply the 2 following files :

```
kubectl apply -f mysql.yaml
kubectl apply -f wordpress.yaml
```

Look at the kubernete dashboard or check with the following commands :

```
kubectl get pvc
kubectl get svc wordpress
```

You can look at your new wordpress following the host value in the Ingress config :
http://wp.mydomain.com


### Tear down

To clean up all the artifacts created by the demo :

```
kubectl delete -f wordpress.yaml
kubectl delete -f mysql.yaml
kubectl delete -n rook-ceph pool replicapool
kubectl delete storageclass rook-ceph-block
```



## Shared File Sytem Storage

### Craete the file system

The Rook operator will create all the pools and other resources necessary to start the service :

Edit `filesystem.yaml` :

```
apiVersion: ceph.rook.io/v1beta1
kind: Filesystem
metadata:
  name: myfs
  namespace: rook-ceph
spec:
  # The metadata pool spec
  metadataPool:
    replicated:
      # Increase the replication size if you have more than one osd
      size: 3
  # The list of data pool specs
  dataPools:
    - failureDomain: osd
      replicated:
        size: 3
      # If you have at least three osds, erasure coding can be specified
      # erasureCoded:
      #   dataChunks: 2
      #   codingChunks: 1
  # The metadata service (mds) configuration
  metadataServer:
    # The number of active MDS instances
    activeCount: 1
    # Whether each active MDS instance will have an active standby with a warm metadata cache for faster failover.
    # If false, standbys will be available, but will not have a warm cache.
    activeStandby: true
    # The affinity rules to apply to the mds deployment
    placement:
    resources:


```

```
kubectl apply -f filesystem.yaml
```

After few minutes check that mds pod are running :

```
kubectl -n rook-ceph get pod -l app=rook-ceph-mds
```




### Consume storage

Then we can consume the storage with the "registry sample"
in the `cluster/examples/kubernete` folder :


Edit `kube-registry.yaml` to have something like the following :

```
apiVersion: v1
kind: ReplicationController
metadata:
  name: kube-registry-v1
  namespace: kube-system
  labels:
    k8s-app: kube-registry
    version: v1
    kubernetes.io/cluster-service: "true"
spec:
  replicas: 3
  selector:
    k8s-app: kube-registry
    version: v1
  template:
    metadata:
      labels:
        k8s-app: kube-registry
        version: v1
        kubernetes.io/cluster-service: "true"
    spec:
      containers:
      - name: registry
        image: registry:2
        resources:
          limits:
            cpu: 100m
            memory: 100Mi
        env:
        - name: REGISTRY_HTTP_ADDR
          value: :5000
        - name: REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY
          value: /var/lib/registry
        # same seceret on all containers
        - name: REGISTRY_HTTP_SECRET
          value: myawsomesecret
        volumeMounts:
        - name: image-store
          mountPath: /var/lib/registry
        ports:
        - containerPort: 5000
          name: registry
          protocol: TCP
      volumes:
      - name: image-store
        flexVolume:
          driver: ceph.rook.io/rook
          fsType: ceph
          options:
            fsName: myfs # name of the filesystem specified in the filesystem CRD.
            clusterNamespace: rook-ceph # namespace where the Rook cluster is deployed
```

Be careful of :

* the `clusterNamespace` instead of `namespace`
* the `REGISTRY_HTTP_SECRET`

Then apply the file :

```
kubectl apply -f kube-registry.yaml
```

Check that or registry pod are running with the following command :

```
kubectl -n kube-system get pods -l k8s-app=kube-registry
```


### Use our registry

To be able to use our new registry we need to create a service and an ingress.

Create a new file called `registry-ingress.yaml` with the following content :

```
---
kind: Service
apiVersion: v1
metadata:
  name: registry-svc
  namespace: kube-system
spec:
  selector:
    k8s-app: kube-registry
  ports:
    - port: 5000
      targetPort: 5000
---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: registry-ingress
  namespace: kube-system
spec:
  rules:
  - host: registry.mydomain.com
    http:
      paths:
      - path: /
        backend:
          serviceName: registry-svc
          servicePort: 5000
  # tls:
  #  - secretName: traefik-ui-tls-cert
```

Then apply the file :

```
kubectl apply -f registry-ingress.yaml
```

If you have un self signed certificate,
on your local machine as root create a file `/etc/docker/daemon.json` with the following content :

```
{
	  "insecure-registries" : ["registry.mydomain.com"]
}
```
Then restart the docker dameon :

```
systemctl restart docker
```

Get a basic docker image from public registry :

```
docker pull hello-world:latest
```


Tag it for our new registry :
```
docker tag hello-world:latest registry.mydomain.com/hello-world:latest
```
Push it to our new registry :

```
docker push registry.mydomain.com/hello-world:latest
```


### Tear down

To clean up all the artifacts created by the demo :

```
kubectl delete -f kube-registry.yaml
kubectl -n rook-ceph delete Filesystem myfs
```
