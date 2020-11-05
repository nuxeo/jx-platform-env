#!/bin/bash -eu
#
# NXBT-3277: Patch 'jenkins-pod-xml-jx-base' and 'jenkins-pod-xml-ai-*' XML config maps with YAML toleration spec
#
# Unfortunately, tolerations cannot be defined through values.yaml because the Kubernetes plugin for
# Jenkins doesn't take them into account when reading a pod template.
# The solution is to use a `yaml` field in the pod template, yet it isn't taken into account by the jenkins-x-platform chart.
# Thus this patch.
#
# Contributors:
#   Antoine Taillefer
#   Julien Carsique
#
for configmap in $(kubectl -n "${NAMESPACE}" get configmap -l jenkins.io/kind=podTemplateXml -o name); do
    echo "Reading $configmap ..."
    name=${configmap#*pod-xml-}
    configXML=$(kubectl -n "${NAMESPACE}" get $configmap -o jsonpath='{.data.config\.xml}')
    if ! (echo "$configXML" | grep -q '<nodeSelector>team=platform</nodeSelector>'); then
        continue
    fi
    yamlPatch="$(cat templates/jenkins-pod-xml-toleration-patch.xml)"
    export CONFIG_XML_PATCHED=$(echo "$configXML" | awk -v yaml="$yamlPatch" "/<label>jenkins-$name<\/label>/ { print; print yaml; next }1" | awk '{print "    "$0}')
    envsubst '$CONFIG_XML_PATCHED' < templates/jenkins-pod-xml-toleration-patch.yaml > templates/jenkins-pod-xml-toleration-patch.yaml~gen
    kubectl -n "${NAMESPACE}" patch "$configmap" --patch "$(cat templates/jenkins-pod-xml-toleration-patch.yaml~gen)"
    echo
done
