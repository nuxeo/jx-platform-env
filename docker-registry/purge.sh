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

pattern=$([ -z "$1" ] && echo -n "PR" || echo -n "$1")
deleteCacheImages=$([ "$2" = "true" ] && echo -n "true" || echo -n "false")

echo '==================================='
echo '- Purge internal Docker registry! -'
echo '==================================='
echo
echo '  Parameters:'
echo "    - pattern: ${pattern}"
echo "    - delete cache images: ${deleteCacheImages}"
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

for image in $images
do
  echo "Handle image named $image"
  imagePattern=$pattern
  if [ "${deleteCacheImages}" = "true" -a "${image%/cache}/cache" = "${image}" ]; then
    # remove all tags pour cache images
    imagePattern=''
  fi
  tags=$(curl --silent http://$dockerRegistryIP:5000/v2/$image/tags/list  | jq -r '.tags | .[]?' | grep "$imagePattern" || true)
  echo "Tags matching pattern '$imagePattern':"
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
