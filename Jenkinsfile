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
    JX_VERSION = '2.0.1849'
    NAMESPACE = getTargetNamespace()
  }
  stages {
    stage('Upgrade Jenkins X') {
      steps {
        setGitHubBuildStatus('upgrade', 'Upgrade Jenkins X', 'PENDING')
        container('jx-base') {
          echo "Upgrade Jenkins X in the ${NAMESPACE} namespace using jenkins image tag ${getJenkinsImageTag()}"
          script {
            // get the existing docker registry auth
            def dockerRegistryConfig = sh(script: 'kubectl get secret jenkins-docker-cfg -n ${NAMESPACE} -o go-template=\$\'{{index .data "config.json"}}\' | base64 --decode | tr -d \'\\n\'', returnStdout: true).trim();
            // get the existing nexus password
            def packagesPassword = sh(script: 'kubectl get secret packages.nuxeo.com-auth -n ${NAMESPACE} -o=jsonpath=\'{.data.password}\' | base64 --decode', returnStdout: true)
            // get the existing Connect credentials
            def connectUsername = sh(script: 'kubectl get secret connect-prod -n ${NAMESPACE} -o=jsonpath=\'{.data.username}\' | base64 --decode', returnStdout: true)
            def connectPassword = sh(script: 'kubectl get secret connect-prod -n ${NAMESPACE} -o=jsonpath=\'{.data.password}\' | base64 --decode', returnStdout: true)
            // upgrade Jenkins
            withEnv([
              "INTERNAL_DOCKER_REGISTRY=${DOCKER_REGISTRY}",
              "DOCKER_REGISTRY_CONFIG=${dockerRegistryConfig}",
              "PACKAGES_PASSWORD=${packagesPassword}",
              "CONNECT_USERNAME=${connectUsername}",
              "CONNECT_PASSWORD=${connectPassword}",
            ]) {
              sh """
                # initialize Helm without installing Tiller
                helm init --client-only

                # add local chart repository
                helm repo add jenkins-x http://chartmuseum.jenkins-x.io

                # replace env vars in values.yaml
                # specify them explicitly to not replace DOCKER_REGISTRY which needs to be relative to the upgraded namespace:
                # platform-staging (PR) or platform (master)
                envsubst '\${NAMESPACE} \${INTERNAL_DOCKER_REGISTRY} \${DOCKER_REGISTRY_CONFIG} \${PACKAGES_PASSWORD} \${CONNECT_USERNAME} \${CONNECT_PASSWORD}' < values.yaml > myvalues.yaml
                # replace env vars in templates/docker-service.yaml
                envsubst '\${NAMESPACE}' < templates/docker-service.yaml > templates/docker-service.yaml~gen

                # create or update Docker Ingress/Service
                kubectl apply -f templates/docker-service.yaml~gen

                # upgrade Jenkins X
                jx upgrade platform --namespace=${NAMESPACE} \
                  --version ${JX_VERSION} \
                  --local-cloud-environment \
                  --always-upgrade \
                  --cleanup-temp-files=true \
                  --batch-mode

                # log jenkins deployment image
                kubectl get deployments.apps jenkins -n ${NAMESPACE} -oyaml -o'jsonpath={ .spec.template.spec.containers[0].image }'

                # patch Jenkins deployment to add Nexus Docker registry pull secret
                kubectl patch deployment jenkins -n ${NAMESPACE} --patch "\$(cat templates/jenkins-master-deployment-patch.yaml)"

                # Patch nuxeo-platform-11 PodTemplate XML ConfigMap to define tolerations and allow the pods being
                # scheduled on a dedicated node pool, see https://jira.nuxeo.com/browse/NXBT-3277.
                ./scripts/pod-template-toleration-patch.sh

                # restart Jenkins pod
                kubectl scale deployment jenkins -n ${NAMESPACE} --replicas 0
                kubectl scale deployment jenkins -n ${NAMESPACE} --replicas 1
              """
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
