#!/bin/bash

# Configuration
#REGISTRY_URL="http://192.168.49.2:30500"
#TAGS_TO_KEEP=3
#DRY_RUN=false  # true to simulate, false to actually delete, this is very useful for production environments

# Functions

get_repositories() {
  curl -s "${REGISTRY_URL}/v2/_catalog" | jq -r '.repositories[]'
}

get_tags() {
  local repo=$1
  curl -s "${REGISTRY_URL}/v2/${repo}/tags/list" | jq -r '.tags[]?'
}

# We consider both Docker and OCI manifests since if we use skopeo it uploads the images in OCI format and fails.
get_digest() {
  local repo=$1
  local tag=$2
  curl -sI -H "Accept: application/vnd.docker.distribution.manifest.v2+json, application/vnd.oci.image.manifest.v1+json" \
    "${REGISTRY_URL}/v2/${repo}/manifests/${tag}" | grep -i Docker-Content-Digest | awk '{print $2}' | tr -d $'\r'
}

delete_digest() {
  local repo=$1
  local digest=$2

  if [ "$DRY_RUN" = true ]; then
    echo "    [DRY RUN] Deleting digest $digest from repo $repo"
  else
    status_code=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE \
      "${REGISTRY_URL}/v2/${repo}/manifests/${digest}")
    if [ "$status_code" = "202" ]; then
      echo "    Deletion successful."
    else
      echo "    Failed to delete (HTTP status $status_code)."
    fi
  fi
}

# Main

echo "Starting cleanup of registry $REGISTRY_URL..."

for repo in $(get_repositories); do

  echo
  echo "---------------------------------------------"
  echo
  echo "Repository: $repo"
  tags=( $(get_tags "$repo" | sort -Vr) )

  if [ ${#tags[@]} -eq 0 ]; then
    echo "  No tags found."
    continue
  fi

  # Keep the first N, delete the rest
  keep_tags=( "${tags[@]:0:$TAGS_TO_KEEP}" )
  delete_tags=( "${tags[@]:$TAGS_TO_KEEP}" )

  echo "  Keeping: ${keep_tags[*]}"
  if [ ${#delete_tags[@]} -eq 0 ]; then
    echo "  Nothing to delete."
    continue
  fi

  for tag in "${delete_tags[@]}"; do
    digest=$(get_digest "$repo" "$tag")
    if [ -z "$digest" ]; then
      echo "  Could not obtain digest for $tag"
      continue
    fi

    echo "  Deleting tag '$tag' (digest: $digest)..."
    delete_digest "$repo" "$digest"
  done
  echo
done

