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

void getReleaseVersion() {
  return sh(returnStdout: true, script: 'jx-release-version')
}

pipeline {
  agent {
    label 'jenkins-jx-base'
  }
  environment {
    CHART_REPOSITORY = 'http://chartmuseum.jenkins-x.io'
  }
  stages {
    stage('Validate environment') {
      steps {
        setGitHubBuildStatus('validate', 'Validate environment', 'PENDING')
        container('jx-base') {
          sh 'helm init --client-only --service-account jenkins'
          sh 'jx step helm build -d platform-env --verbose'
        }
      }
      post {
        success {
          setGitHubBuildStatus('validate', 'Validate environment', 'SUCCESS')
        }
        failure {
          setGitHubBuildStatus('validate', 'Validate environment', 'FAILURE')
        }
      }
    }
    stage('Update environment') {
      // when {
      //   branch 'master'
      // }
      steps {
        setGitHubBuildStatus('update', 'Update environment', 'PENDING')
        container('jx-base') {
          sh 'jx step helm apply -d platform-env --name platform-env --namespace test-platform-env  --verbose'
        }
      }
      post {
        // always {
        //   step([$class: 'JiraIssueUpdater', issueSelector: [$class: 'DefaultIssueSelector'], scm: scm])
        // }
        success {
          setGitHubBuildStatus('update', 'Update environment', 'SUCCESS')
        }
        failure {
          setGitHubBuildStatus('update', 'Update environment', 'FAILURE')
        }
      }
    }
  }
}
