/*
 * (C) Copyright 2019 Nuxeo (http://nuxeo.com/) and others.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * Contributors:
 *     Antoine Taillefer <ataillefer@nuxeo.com>
 */
 properties([
  [$class: 'GithubProjectProperty', projectUrlStr: 'https://github.com/nuxeo/jx-platform-env/'],
  [$class: 'BuildDiscarderProperty', strategy: [$class: 'LogRotator', daysToKeepStr: '60', numToKeepStr: '60', artifactNumToKeepStr: '5']],
  disableConcurrentBuilds(),
])

void setGitHubBuildStatus(String context, String message, String state) {
  step([
    $class: 'GitHubCommitStatusSetter',
    reposSource: [$class: 'ManuallyEnteredRepositorySource', url: 'https://github.com/nuxeo/jx-platform-env'],
    contextSource: [$class: 'ManuallyEnteredCommitContextSource', context: context],
    statusResultSource: [$class: 'ConditionalStatusResultSource', results: [[$class: 'AnyBuildResult', message: message, state: state]]],
  ])
}

String getReleaseVersion() {
  return sh(returnStdout: true, script: 'jx-release-version')
}

String getJenkinsImageTag() {
  return sh(returnStdout: true, script: "grep ImageTag values.yaml | awk '{print \$2}'")
}

String getTargetNamespace() {
  return BRANCH_NAME == 'master' ? 'platform' : 'platform-staging'
}

pipeline {
  agent {
    label 'jenkins-jx-base'
  }
  environment {
    JX_VERSION = '2.0.2412'
    HELM_VERSION = '2.16.6'
    NAMESPACE = getTargetNamespace()
    JENKINS_IMAGE_DOCKER_REGISTRY = "${DOCKER_REGISTRY}"
    INTERNAL_DOCKER_REGISTRY = "docker.${NAMESPACE}.dev.nuxeo.com"
  }
  stages {
    stage('Upgrade Jenkins X') {
      steps {
        setGitHubBuildStatus('upgrade', 'Upgrade Jenkins X', 'PENDING')
        container('jx-base') {
          echo "Upgrade Jenkins X in the ${NAMESPACE} namespace using jenkins image tag ${getJenkinsImageTag()}"
          script {
            withCredentials([
              string(credentialsId: 'jenkins-docker-cfg', variable: 'DOCKER_REGISTRY_CONFIG'),
              usernamePassword(credentialsId: 'packages.nuxeo.com-auth', usernameVariable: 'PACKAGES_USERNAME', passwordVariable: 'PACKAGES_PASSWORD'),
              usernamePassword(credentialsId: 'connect-prod', usernameVariable: 'CONNECT_USERNAME', passwordVariable: 'CONNECT_PASSWORD'),
            ]) {
              // install a more recent version of Helm 2 for Helm to correctly detect the API version capabilities
              // of the server in the chart manifests (jenkins and others):
              // {{- if .Capabilities.APIVersions.Has "apps/v1" }}
              // apiVersion: apps/v1
              // {{- else }}
              // apiVersion: apps/v1beta1
              // {{- end }}
              echo 'Current Helm version:'
              sh 'helm version'

              sh "wget -qO - https://get.helm.sh/helm-v$HELM_VERSION-linux-amd64.tar.gz | tar -xzvf - --strip-components=1 -C /usr/bin linux-amd64/helm"
              echo 'New Helm version:'
              sh 'helm version'

              echo 'initialize Helm without installing Tiller'
              sh 'helm init --client-only --stable-repo-url=https://charts.helm.sh/stable'

              echo 'add local chart repository'
              sh 'helm repo add jenkins-x http://chartmuseum.jenkins-x.io'

              echo 'replace env vars'
              sh """
                envsubst < values.yaml > myvalues.yaml
                envsubst < templates/docker-service.yaml > templates/docker-service.yaml~gen
              """

              echo 'create or update Docker Ingress/Service'
              sh 'kubectl apply -f templates/docker-service.yaml~gen'

              echo 'jx version:'
              sh 'jx version --no-verify=true --no-version-check=true'

              echo 'upgrade Jenkins X Platform'
              sh """
                jx upgrade platform --namespace=${NAMESPACE} \
                  --version ${JX_VERSION} \
                  --local-cloud-environment \
                  --always-upgrade \
                  --cleanup-temp-files=true \
                  --batch-mode
              """

              // echo 'log jenkins deployment image'
              // sh "kubectl get deployments.apps jenkins -n ${NAMESPACE} -oyaml -o'jsonpath={ .spec.template.spec.containers[0].image }'"

              // echo 'patch Jenkins deployment to add Nexus Docker registry pull secret'
              // sh """
              //   kubectl patch deployment jenkins -n ${NAMESPACE} --patch "\$(cat templates/jenkins-master-deployment-patch.yaml)"
              // """

              // echo """
              //   Patch pod template XML ConfigMaps to define tolerations and allow the pods being
              //   scheduled on a dedicated node pool, see https://jira.nuxeo.com/browse/NXBT-3277.
              // """
              // sh './scripts/pod-template-toleration-patch.sh'

              // echo "restart Jenkins pod"
              // sh """
              //   kubectl scale deployment jenkins -n ${NAMESPACE} --replicas 0
              //   kubectl scale deployment jenkins -n ${NAMESPACE} --replicas 1
              // """
            }
          }
        }
      }
      post {
        success {
          setGitHubBuildStatus('upgrade', 'Upgrade Jenkins X', 'SUCCESS')
        }
        failure {
          setGitHubBuildStatus('upgrade', 'Upgrade Jenkins X', 'FAILURE')
        }
      }
    }
    stage('Perform Git release') {
      when {
        branch 'master'
      }
      steps {
        setGitHubBuildStatus('git-release', 'Perform Git release', 'PENDING')
        container('jx-base') {
          withEnv(["VERSION=${getReleaseVersion()}"]) {
            sh """
              # ensure we're not on a detached head
              git checkout master

              # create the Git credentials
              jx step git credentials
              git config credential.helper store

              # Git tag
              jx step tag -v ${VERSION}

              # Git release
              jx step changelog -v v${VERSION}
            """
          }
        }
      }
      post {
        always {
          step([$class: 'JiraIssueUpdater', issueSelector: [$class: 'DefaultIssueSelector'], scm: scm])
        }
        success {
          setGitHubBuildStatus('git-release', 'Perform Git release', 'SUCCESS')
        }
        failure {
          setGitHubBuildStatus('git-release', 'Perform Git release', 'FAILURE')
        }
      }
    }
  }
}
