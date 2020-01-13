# Jenkins X Environment of the Platform Team

This repository allows to configure the [platform](https://jenkins.platform.dev.nuxeo.com/) and [platform-staging](https://jenkins.platform-staging.dev.nuxeo.com/) Jenkins X teams, according to [values.yaml](values.yaml).

When opening a pull request, it triggers an upgrade of Jenkins X in the `platform-staging` team.

If the upgrade is validated - and it references a release version of the Jenkins image, see the [jx-platform-jenkins](https://github.com/nuxeo/jx-platform-jenkins/) upstream repository - the pull request can be merged. This triggers an upgrade of Jenkins X in the `platform` team.

Note that we only build the `master` branch of the repositories imported in the `platform-staging` team.

Documentation about the `platform-staging` team setup can be found [here](docs/platform-staging-setup.md).
