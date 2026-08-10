pipeline {
    agent {
        label 'linux'
    }

    triggers {
        githubPush()
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Run Testbenches') {
            steps {
                sh '''
                make all
                '''
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'logs/*.log', fingerprint: true, allowEmptyArchive: true
        }

        success {
            echo "All tests passed."
        }

        failure {
            echo "One or more tests failed."
        }
    }
}