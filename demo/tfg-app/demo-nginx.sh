#!/bin/bash

# Define the base repository
repo="tfg-dev.core.harbor.dev.lab/tfg-app/nginx"

# List of tags in the desired order
tags=("0.0.0" "0.0.1" "0.0.2" "0.0.3" "0.0.4")

# Iterate over each tag and perform the push
for tag in "${tags[@]}"; do
  echo -e "\nPushing image $repo:$tag..."
  docker push "$repo:$tag"

  # Check if the push was successful
  if [ $? -eq 0 ]; then
    echo "Push of $repo:$tag completed successfully."
  else
    echo "Error pushing image $repo:$tag."
    exit 1
  fi

  # Wait 60 seconds before the next iteration, except after the last one
  if [ "$tag" != "0.0.3" ]; then
    echo -e "\nWaiting 60 seconds before the next push..."
    sleep 60
  fi
done

echo "All pushes have been completed."

