# Setup of the platform-staging Jenkins X Team

## Prerequisite

- The `platform-staging` team is created with TLS.
- An OAuth application exists in GitHub.

## Secrets

Copy secrets from the platform namespace to the platform-staging namespace:

```shell
kubectl get secret jenkins-docker-cfg --namespace=platform --export -o yaml |\
   kubectl apply --namespace=platform-staging -f -

kubectl get secret jenkins-secrets --namespace=platform --export -o yaml |\
   kubectl apply --namespace=platform-staging -f -
```

## GitHub OAuth

Update the GitHub OAuth credentials.

```shell
kubectl get secret jenkins-secrets -o json | jq --arg value "$(echo GITHUB_OAUTH_CLIENT_ID | base64)" '.data["GITHUB_ID"]=$value' | kubectl apply -f -
kubectl get secret jenkins-secrets -o json | jq --arg value "$(echo GITHUB_OAUTH_SECRET | base64)" '.data["GITHUB_SECRET"]=$value' | kubectl apply -f -
```

## Jenkins X Team

To set up the `platform-staging` Jenkins X team, open a test pull request in [jx-platform-env](https://github.com/nuxeo/jx-platform-env/) to trigger the related [job](https://jenkins.platform.dev.nuxeo.com/job/nuxeo/job/jx-platform-env).

Then, manually fix the Jenkins URL in the Jenkins configuration UI.

In https://jenkins.platform-staging.dev.nuxeo.com/configure, replace

```shell
http://jenkins.platform-staging.34.74.59.50.nip.io/
```

by

```shell
https://jenkins.platform-staging.dev.nuxeo.com/
```

Finally, [download](https://jenkins.platform-staging.dev.nuxeo.com/configuration-as-code/) and check the YAML configuration as code:

```yaml
unclassified:
  gitHubPluginConfig:
    hookUrl: "https://jenkins.platform-staging.dev.nuxeo.com/github-webhook/"
  location:
    url: "https://jenkins.platform-staging.dev.nuxeo.com/"
```

## Project Imports

First, get the API token for the Jenkins admin user:

```shell
kubectl get secret -n platform-staging jenkins -o jsonpath='{.data.jenkins-admin-api-token}' | base64 --decode
```

Then import the following projects:

```shell
jx import --disable-updatebot --no-draft --branches master --url https://github.com/nuxeo/nuxeo-helm-charts
jx import --disable-updatebot --no-draft --branches master --url https://github.com/nuxeo/jx-platform-builders
jx import --disable-updatebot --no-draft --branches master --url https://github.com/nuxeo/nuxeo
jx import --disable-updatebot --no-draft --jenkinsfile Jenkinsfiles/build-status.groovy --branches master --url https://github.com/nuxeo/nuxeo-jsf-ui
jx import --disable-updatebot --no-draft --branches master --url https://github.com/nuxeo/nuxeo-arender-connector
```

When importing, answer as following:

```shell
? Jenkins username: admin
? API Token: **********************************
? Do you wish to use nuxeo-platform-jx-bot as the Git user name: Y
```

For each project, remove the following webhook created automatically in the related GitHub repository:

```shell
https://jenkins.platform-staging.dev.nuxeo.com/github-webhook/
```

Rename the `nuxeo-jsf-ui` project to `nuxeo-jsf-ui-status`.
