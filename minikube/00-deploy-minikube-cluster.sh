#!/bin/bash

# Resource configuration
CPUS=2
MEMORY=4096
DISK_SIZE=80g
insecure_registry="192.168.49.2:30500"
cni="calico"

# Verify if Minikube is already running
if minikube status | grep -q "Running"; then
    echo "Minikube is already running."
    exit 0
else
    echo "Starting Minikube with ${CPUS} CPUs, ${MEMORY}MB RAM and ${DISK_SIZE} disk..."
    minikube start --cpus=$CPUS --memory=$MEMORY --disk-size=$DISK_SIZE --insecure-registry=$insecure_registry --cni=$cni
fi

# Enable addons
echo
echo "Enabling addons in Minikube..."

echo
echo "Enabling Ingress Controller..."
minikube addons enable ingress

echo
echo "Enabling Metrics Server..."
minikube addons enable metrics-server

echo
echo "Enabling Registry..."
minikube addons enable registry

# Enable NodePort svc for the registry
kubectl apply -f svc-registry-nodeport.yaml

echo
echo "Minikube is ready with the enabled addons."

