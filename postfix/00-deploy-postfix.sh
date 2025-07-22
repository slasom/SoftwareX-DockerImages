#!/bin/bash

helm upgrade --install --namespace postfix --create-namespace mail bokysan/mail -f values.yaml

#--set persistence.enabled=false
