/* pipeline {
    agent {
        label 'linux'
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
                mkdir -p build logs

                tests=(
                    mod_add
                    mod_mult
                    montgomery
                    to_mont
                    from_mont
                )

                for test in "${tests[@]}"
                do
                    echo "Running $test"
                    rm -rf test.out
                    iverilog \
                        -o build/$test.out \
                        src/arithmetic/*.v \
                        tb/${test}_tb.v

                    vvp build/$test.out > logs/${test}.log

                    if grep -q "FAIL" logs/${test}.log
                    then
                        echo "$test failed."
                        exit 1
                    fi
                done
                '''
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'logs/*.log', fingerprint: true, allowEmptyArchive: true
        }

        success {
            echo 'All hardware tests passed.'
        }

        failure {
            echo 'One or more hardware tests failed.'
        }
    }
} */

pipeline {
    agent {
        label 'linux'
    }

    options {
        skipDefaultCheckout(true)
    }

    stages {
        stage('Check Git') {
            steps {
                sh '''
                echo "PATH=$PATH"
                which git
                git --version
                '''
            }
        }
    }
}