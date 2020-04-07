# Setup of the Platform Jenkins X Team

## Disable GitHub Multibranch Status

### Prerequisite

- Jenkins is installed.
- The [Disable GitHub Multibranch Status](https://plugins.jenkins.io/disable-github-multibranch-status/) plugin is installed.

Open the platform team's [Jenkins](https://jenkins.platform.dev.nuxeo.com/).

For each job, disable the GitHub multibranch status:

- Open the multibranch pipeline configuration, for instance [nuxeo](https://jenkins.platform.dev.nuxeo.com/job/nuxeo/job/nuxeo/configure)

- In Branch Sources > GitHub > Behaviours, click on the "Add" button.

- Select "Disable GitHub Notifications".

- Click on "Save".

## Configure Nexus Docker Registry

### Prerequisite

- Nexus is installed.
- NGINX Ingress Controller is installed in the default namespace.

### Create New Docker Repository

Open the [Nexus Repository Manager](https://nexus.platform.dev.nuxeo.com/). Start new session using admin user

#### Blob Storage

Create a blob storage : `docker-registry`

- In Server Administration and Configuration > Repository > Blob Stores, click on the "Create blob store" button

- Complete all required fields and click on "Save"

#### Repository

Create a docker (hosted) nexus repository: `docker-registry`

- In Server Administration and Configuration > Repository > Repositories, click on the "Create repository" button

- In the Storage section, use the previously created blob store

- Complete all required fields and click on "Save"

### Cleanup Policy Configuration

Create a new policy cleanup and apply it for each nexus docker registry you have created if needed.

#### Create New Cleanup Policy

- In Server Administration and Configuration > Repository > Cleanup Policies, click on the "Create Cleanup Policy" button

- To keep all nuxeo builder and jenkins master images (latest tag for example) add this asset name matcher `~(.*nuxeo/builder-.*/manifests/latest|.*nuxeo/platform.*-jenkinsx/manifests/[0-9]{1,}.[0-9]{1,}.[0-9]{1,})`

- Complete all required fields and click on "Save"

#### Apply Cleanup Policy

- Open the [docker-registry](https://nexus.platform.dev.nuxeo.com/#admin/repository/repositories:docker-registry) repository configuration for instance

- Scroll down to the Cleanup Policies section and select the corresponding item

- Click on "Save".

### Create New Docker Ingress Service

This ingress service will act as reverse proxy for the nexus docker repository.
The reverse proxy will redirect docker commands (pull, push or login) received at:

https://docker.platform.dev.nuxeo.com

to

https://nexus.platform.dev.nuxeo.com/repository/docker-registry/

- Create an ingress configuration file following this [example](../templates/docker-ingress.yaml)

```bash
NAMESPACE=platform
envsubst '${NAMESPACE}' < templates/docker-ingress.yaml > templates/my-docker-ingress.yaml
```

- Create new ingress service from the configuration file

```bash
kubectl create -f templates/my-docker-ingress.yaml
```

- Check if the ingress service is ready

```bash
kubectl get -f templates/my-docker-ingress.yaml
```

- List the catalog from the new nexus docker registry

```bash
DOCKER_REGISTRY=$(kubectl get -f templates/my-docker-ingress.yaml -o json --output=jsonpath={.spec.rules[].host} )
curl https://${DOCKER_REGISTRY}/v2/_catalog
```

### Update the Jenkins X Docker Configuration

An authentication should be configured for the newly created docker registry to enable pushing or pulling images.

Create/update Docker authentication for the newly added [Docker registry](docker.platform.dev.nuxeo.com) in the Jenkins X Docker configuration secret (`jenkins-docker-cfg`).

```bash
NAMESPACE=platform
NEXUS_PASSWORD=$(kubectl get secret nexus -n ${NAMESPACE} -o=jsonpath='{.data.password}' | base64 --decode)
jx create docker auth --host "docker.${NAMESPACE}.dev.nuxeo.com" --user "admin" --secret "${NEXUS_PASSWORD}"
```

If building your images with Kaniko, you have to specify the Kubernetes secret that contains the config.json Docker configuration in all the skaffold.yaml files.

```yaml
cluster:
  ...
  dockerConfig:
    secretName: jenkins-docker-cfg
```

### Allow Kubernetes to Pull Images

#### Create a Secret Based on Existing Docker Credentials

We suppose the Kubernetes secret `jenkins-docker-cfg` already exists in the `platform` namespace:

```bash
kubectl create secret generic kubernetes-docker-cfg \
    --from-literal=.dockerconfigjson="$(kubectl get secret jenkins-docker-cfg -ojsonpath='{.data.config\.json}' | base64 --decode)" \
    --type=kubernetes.io/dockerconfigjson
```

Unfortunately, `kubernetes-docker-cfg` and `jenkins-docker-cfg` can seem duplicated, it is due to secret format:

- Kubernetes expects to have a secret with the `kubernetes.io/dockerconfigjson` type and data to be stored in `data/.dockerconfigjson`.

- Kaniko expects to have a secret with the `Opaque` type and data to be stored in `data/config.json`.

> The `kubernetes-docker-cfg` and `jenkins-docker-cfg` secrets must be kept synchronized.

##### Allow Docker Secret to Be Replicated

To enable secret replicator for `kubernetes-docker-cfg` , apply this patch on it.

```bash
  kubectl patch secret/kubernetes-docker-cfg -n ${NAMESPACE} --patch "\$(cat templates/kubernetes-docker-cfg-patch.yaml)"
```

You can create the new secret replica using this template file:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: kubernetes-docker-cfg-replica
  namespace:  nuxeo-arender
  annotations:
    replicator.v1.mittwald.de/replicate-from: platform/kubernetes-docker-cfg
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: e30K
```

> More information is available at [kubernetes-replicator](https://github.com/mittwald/kubernetes-replicator#special-case-docker-registry-credentials).

#### Configure Pod Templates

If a PodTemplate needs to retrieve an image from the nexus docker repository, this line must be added:

```yaml
  Agent:
    PodTemplates:
      Nuxeo-Package-11:
        ImagePullSecret: kubernetes-docker-cfg
```
