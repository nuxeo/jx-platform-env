# How to setup AWS Credentials rotation

These files have to be deployed in the platform namespace.

## prerequisite

  ```text
  - you have access to kubernetes cluster hosting 'platform' namespace.
  - docker image 'nuxeo/aws-iam-credential-rotate' is available.
  - create or retrieve credentials from AWS:
    - Access key ID
    - Secret access key
  ```

## Create Secret

secret will be created under the 'platform' namespace:

```bash
kubectl create -f templates/secret.yaml
```

## Create Service Account, Role, Rolebinding and Cronjob

cronjob file will create these objects under the 'platform' namespace:

- [service account](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/)
- [role](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#role-and-clusterrole)
- [rolebinding](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#rolebinding-and-clusterrolebinding)
- [cronjob](https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/)

```bash
kubectl create -f templates/cronjob.yaml
```

> More information is available at [AWS IAM key rotate tool](https://github.com/nuxeo-cloud/aws-iam-credential-rotate).
