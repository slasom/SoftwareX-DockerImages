#!/bin/sh
# Diun script

# Declaration of variables
NOW=`date +%A_%d%m%y_%H%M`
ruta_error=/data/logs
ruta_ok=$ruta_error
entry_image=$DIUN_ENTRY_IMAGE
internal_registry_kubernetes="192.168.49.2:30500"
image_registry_kube=${entry_image:28}
deploy_name=${image_registry_kube#*/} # Remove project
deploy_name=${deploy_name%%:*} # Remove version
container_name=$deploy_name
project="tfg-app-dev"


# Function to send informative emails about the process
enviarmensaje () {

subject="¡$1!"
body=$(cat $ruta_error/mensaje_error.txt)
from="containerstfg2025@gmail.com"
to="containerstfg2025@gmail.com"
#echo -e "Subject:${subject}\nBody:${body}" | sendmail -f "${from}" -S "192.168.49.2:30000" -t "${to}"
echo -e "Subject: ${subject}\n\n${body}" | sendmail -f "${from}" -S "192.168.49.2:30000" -t "${to}"
rm -f $ruta_error/mensaje_error.txt
}

enviarmensaje_ok () {

subject="¡$1!"
body=$(cat $ruta_ok/mensaje_ok.txt)
from="containerstfg2025@gmail.com"
to="containerstfg2025@gmail.com"
#echo -e "Subject:${subject}\nBody:${body}" | sendmail -f "${from}" -S "192.168.49.2:30000" -t "${to}"
echo -e "Subject: ${subject}\n\n${body}" | sendmail -f "${from}" -S "192.168.49.2:30000" -t "${to}"
rm -f $ruta_ok/mensaje_ok.txt
}

### Empty logs
rm -f logs/*

### CI - Transfer image to internal repository 

echo -e "\n  Running: CI - Transfer image to internal repository... "

skopeo copy --src-tls-verify=false --dest-tls-verify=false docker://$entry_image docker://$internal_registry_kubernetes/$image_registry_kube >/dev/null 2>>$ruta_error/logs_error.txt 

# Send email
if [ ! $? -eq 0 ];
  then
   echo "ATENTION: An error occurred while transferring via skopeo from $entry_image to $internal_registry_kubernetes/$image_registry_kube"  >> $ruta_error/mensaje_error.txt
   enviarmensaje "Docker Diun: Error transferring image $image_registry_kube via skopeo"
   echo -e "\n  Error occurred while executing the CI process, you can check the errors in the received email"
   exit
  else
   echo "Process completed: the image '$image_registry_kube' has been successfully published to the internal Kubernetes registry ('$internal_registry_kubernetes')." >> $ruta_error/mensaje_ok.txt

   cat $ruta_error/mensaje_ok.txt >> test.txt
   enviarmensaje_ok "Docker Diun: New image published to internal Kubernetes registry: $image_registry_kube"
   echo -e "\n  CI process completed successfully."
fi


### CD-Kubernetes Development Environment 

#sleep 5

echo -e "\n Running: CD-Kubernetes Development Environment... "

# Check if the Deployment exists in the specified namespace
if kubectl get deployment "$deploy_name" -n "$project" &> /dev/null; then
    echo "The Deployment '$deploy_name' already exists in the namespace '$project'. Updating the image..."
    # Update the container image in the existing Deployment
    kubectl patch deployment "$deploy_name" -n "$project" --type='json' -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/imagePullPolicy", "value":"Always"}]' >/dev/null 
    kubectl set image deployment/"$deploy_name" "$container_name"="$internal_registry_kubernetes/$image_registry_kube" -n "$project" >/dev/null 
    status=$?
else
    echo "The Deployment '$deploy_name' does not exist in the namespace '$project'. Creating it..."
    # Create a new Deployment with the specified image
    kubectl create ns "$project" >/dev/null 2>&1  # If the ns does not exist, create it, if it exists do nothing.
    kubectl create deployment "$deploy_name" --image="$internal_registry_kubernetes/$image_registry_kube" -n "$project" >/dev/null 
    kubectl patch deployment "$deploy_name" --type='json' -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/imagePullPolicy", "value":"Always"}]' >/dev/null 

    kubectl expose deployment "$deploy_name" --port=80 --target-port=80 --name=$deploy_name-service -n "$project" >/dev/null 
    kubectl patch service $deploy_name-service -p '{"spec": {"type": "NodePort"}}' -n "$project"  >/dev/null 
    status=$?
fi

# Send email
if [ ! $status -eq 0 ]; then
  # Messages in case of error
  echo "ATENTION: An error occurred while deploying the image '$image_registry_kube' in the deployment '$deploy_name' of the project '$project'." >/dev/null 2>>$ruta_error/mensaje_error.txt
  enviarmensaje "Docker Diun: Error deploying the image '$image_registry_kube' in the deployment '$deploy_name' of the project '$project'."
  echo -e "\n  Error occurred while executing the CD process, you can check the errors in the received email"
  exit 1
else
  # Messages in case of success
  echo "Process completed: the image '$image_registry_kube' has been successfully deployed in the deployment '$deploy_name' of the project '$project'." >> $ruta_error/mensaje_ok.txt
  NODE_PORT=$(kubectl get svc $deploy_name-service -o jsonpath='{.spec.ports[0].nodePort}' -n $project)
  echo "To access the app you can use the following url: http://192.168.49.2:$NODE_PORT" >> $ruta_error/mensaje_ok.txt
  enviarmensaje_ok "Docker Diun: Successful deployment of the image '$image_registry_kube' in the deployment '$deploy_name' of the project '$project'"
  echo -e "\n  CD process completed successfully."
fi

