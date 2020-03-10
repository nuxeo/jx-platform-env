# Setup of the platform Jenkins X Team

## Prerequisite

- Jenkins is installed.
- The [Disable GitHub Multibranch Status](https://plugins.jenkins.io/disable-github-multibranch-status/) plugin is installed.

## Disable GitHub Multibranch Status

Open the platform team's [Jenkins](https://jenkins.platform.dev.nuxeo.com/).

For each job, disable the GitHub multibranch status:

- Open the multibranch pipeline configuration, for instance [nuxeo](https://jenkins.platform.dev.nuxeo.com/job/nuxeo/job/nuxeo/configure)

- In Branch Sources > GitHub > Behaviours, click on the "Add" button.

- Select "Disable GitHub Notifications".

- Click on "Save".
