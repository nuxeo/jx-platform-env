#!/bin/sh
set -e

dockerRegistryPod=$(kubectl get pod -o custom-columns=NAME:.metadata.name | grep docker-registry)
dockerRegistryIP=$(kubectl get svc -o custom-columns=NAME:.metadata.name,CLUSTER-IP:.spec.clusterIP | grep docker-registry | awk '{print $2}')

function execDockerRegistry () {
  kubectl exec $dockerRegistryPod -- $1
}

function space () {
  execDockerRegistry "df" | grep 'Filesystem\|/var/lib/registry'
}

function used () {
  execDockerRegistry "df" | grep '/var/lib/registry' | awk '{print$3}'
}

echo '==================================='
echo '- Purge internal Docker registry! -'
echo '==================================='
echo

echo 'Space before cleanup:'
space
echo

usedBefore=$(used)

images=$(curl --silent http://$dockerRegistryIP:5000/v2/_catalog | jq -r '.repositories | .[]?')
echo 'Images to handle:'
cat << EOF
$images
EOF
echo

pattern=PR
for image in $images
do
  echo "Handle image named $image"
  tags=$(curl --silent http://$dockerRegistryIP:5000/v2/$image/tags/list  | jq -r '.tags | .[]?' | grep $pattern || true)
  echo "Tags matching pattern '$pattern':"
  cat << EOF
$tags
EOF
  if [ -z "$tags" ]; then
    continue
  fi
  echo
  for tag in $tags
  do
    rawDigest=$(curl -v --silent -H 'Accept: application/vnd.docker.distribution.manifest.v2+json' http://$dockerRegistryIP:5000/v2/$image/manifests/$tag 2>&1 | grep Docker-Content-Digest | awk '{print $3}')
    digest=${rawDigest%$'\r'}
    echo "Delete digest of image $image:$tag      $digest"
    curl --silent -X DELETE http://$dockerRegistryIP:5000/v2/$image/manifests/$digest
  done
  echo
done
echo

echo 'Garbage collection:'
execDockerRegistry "/bin/registry garbage-collect /etc/docker/registry/config.yml"
echo

echo 'Space after cleanup:'
space
echo

usedAfter=$(used)
cleanedUp=$((($usedBefore - $usedAfter) / 1024))

echo "Cleaned up $cleanedUp Mo"
echo
