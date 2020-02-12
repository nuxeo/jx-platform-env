# How to setup AWS Credentials rotation

This files have to be deployed in the platform namespace.

- prerequisite

  ```text
  - you have access to kubernetes cluster hosting 'platform' namespace.
  - docker image 'nuxeo/aws-iam-credential-rotate' is available.
  - create or retrieve credentials from aws:
    - Access key ID
    - Secret access key
  ```

## Create Secret

[secret](secret.yaml) file will create under 'platform' namespace:

- aws-iam-user-credentials secret

#### command

```bash
    > $ kubectl create -f templates/secret.yaml
```

## Create Service Account, Role, Rolebinding and Cronjob

[cronjob](cronjob.yaml) file will create under 'platform' namespace this objects:

- aws-credentials-updater service account
- secret-edit role
- aws-credentials-updater-rolebinding rolebinding
- rotate-keys cronjob

#### command

```bash
    > $ kubectl create -f templates/cronjob.yaml
```

> More information is available at [AWS IAM key rotate tool](https://github.com/nuxeo-cloud/aws-iam-credential-rotate).
