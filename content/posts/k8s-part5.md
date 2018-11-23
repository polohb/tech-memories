+++
title = "K8s Part5 - Monitoring"
date = 2018-11-20T11:47:21+01:00
draft = true
tags = ["kubernetes" , "monitoring" , "prometheus", "#grafana"]
categories = []
+++


# What will be covered

* How to deploy Prometheus operator
* How to monitor Rook via Prometheus


# Usefull ressources links

* [prometheus-operator](https://github.com/coreos/prometheus-operator/tree/release-0.25)
* [Rook monitoring](https://rook.github.io/docs/rook/v0.8/monitoring.html)
* [Cluster Monitoring](https://github.com/coreos/prometheus-operator/blob/master/Documentation/user-guides/cluster-monitoring.md)


# Prometheus Operator

Get the prometheus-operator bundle from github :


```
mkdir -p ~/CODE/K8s/monitoring
cd ~/CODE/K8s/monitoring
wget -O prometheus-operator-bundle-0.25.yaml https://raw.githubusercontent.com/coreos/prometheus-operator/release-0.25/bundle.yaml
```

Edit the file to create a specific namespace for monitoring
(add the following in the start of the file) :

```
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring
---
```
And change all `namespace: default` by `namespace: monitoring`.


Apply the file :

```
kubectl apply -f prometheus-operator-bundle-0.25.yaml
```

Check the operator is running :

```
kubectl -n monitoring get pod
```

# Monitoring Rook

Go back to rook examples files folder :

```
cd ../rook/cluster/examples/kubernetes/monitoring
```

First

The ServiceMonitor has a label selector to select Services and their underlying Endpoint objects.


```
kubectl apply -f service-monitor.yaml
```

Enable RBAC rules for Prometheus pods, and create a Prometheus object that defines
the serviceMonitorSelector to specify which ServiceMonitors should be included.


```
kubectl apply -f prometheus.yaml
```


To access the Prometheus instance it must be exposed to the outside.

In the following `prometheus-ingress.yaml` file, we will create a service and an ingress :

```
---
apiVersion: v1
kind: Service
metadata:
  name: rook-prometheus
  namespace: rook-ceph
spec:
  ports:
  - name: web
    port: 9090
    protocol: TCP
    targetPort: web
  selector:
    prometheus: rook-prometheus
---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: rook-prometheus-ingress
  namespace: rook-ceph
spec:
  rules:
  - host: rook-prometheus.mydomain.com
    http:
      paths:
      - path: /
        backend:
          serviceName: ook-prometheus
          servicePort: web
```
Then apply it :
```
kubectl apply -f prometheus-ingress.yaml
```


Then just go to http://rook-prometheus.mydomain.com to view the prometheus interface.


# Grafana

## Deploy

Enable a the StorageClass from Rook if not already done :

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



Create a `grafana.yaml` file with the following content :

```
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: grafana-pv-claim
  namespace: monitoring
  labels:
    app: grafana
spec:
  storageClassName: rook-ceph-block
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
---
apiVersion: apps/v1beta1
kind: Deployment
metadata:
  name: grafana
  namespace: monitoring
  labels:
    k8s-app: grafana
    version: v1
spec:
  selector:
    matchLabels:
      k8s-app: grafana
  strategy:
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
    type: RollingUpdate
  template:
    metadata:
      labels:
        k8s-app: grafana
        version: v1
    spec:
      # grafana as a 472 default user
      # so we need to be abble to write on volumes
      # maybe we can do something better but this work
      securityContext:
        runAsUser: 472
        fsGroup: 472
      containers:
        - image: grafana/grafana
          name: grafana
          ports:
            - containerPort: 3000
              protocol: TCP
          resources:
            limits:
              cpu: 500m
              memory: 2500Mi
            requests:
              cpu: 100m
              memory: 100Mi
          volumeMounts:
            - mountPath: /var/lib/grafana
              name: grafana-persistent-storage
      restartPolicy: Always
      volumes:
        - name: grafana-persistent-storage
          persistentVolumeClaim:
            claimName: grafana-pv-claim
---
apiVersion: v1
kind: Service
metadata:
  name: grafana
  namespace: monitoring
  labels:
    k8s-app: grafana
spec:
  selector:
    k8s-app: grafana
  ports:
    - port: 3000
      protocol: TCP
      targetPort: 3000
---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: grafana-ingress
  namespace: monitoring
spec:
  rules:
  - host: grafana.mydomain.com
    http:
      paths:
      - path: /
        backend:
          serviceName: grafana
          servicePort: 3000
  # tls:
  #  - secretName: traefik-ui-tls-cert
```


We need to set some [Security Context](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/)
to be able to use grafana. The container user id is 472 and not root, so by default he cannot
write to the mounted volume.
Maybe there is a better solution to do this.

Than apply the file :
```
kubectl apply -f grafana.yaml
```



Got to `grafana.mydomain.com` : default credentials are `admin / admin`.



## Configure metrics

Get the internal prometheus-rook metrics url : `http://10.233.97.159:9090`


Add a new data source in grafana.


Import dashboard from :

 * [Ceph - Cluster](https://grafana.com/dashboards/2842)
 * [Ceph - OSD](https://grafana.com/dashboards/5336)
 * [Ceph - Pools](https://grafana.com/dashboards/5342)
