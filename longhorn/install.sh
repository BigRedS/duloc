#! /bin/bash

helm repo add longhorn https://charts.longhorn.io
helm repo update
helm install longhorn longhorn/longhorn \
	--namespace longhorn-system \
	--create-namespace \
	--version 1.8.1 \
	--set defaultSettings.defaultDataPath=/var/lib/k8s/longhorn \
	--set defaultSettings.defaultReplicaCount=1

# k3s sets local-path to the default storageclass, longhorn _adds_ itself as another
# default, so here we unmark local-path as a default:
kubectl patch storageclass local-path	-p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
