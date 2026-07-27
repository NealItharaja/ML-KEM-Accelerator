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
                mkdir -p build logs

                tests="add mod_pipeline" 

                for test in $tests
                do
                    echo "Running $test"
                    rm -f build/$test.out

                    iverilog \
                        -o build/$test.out \
                        src/arithmetic/*.v \
                        testbench/arithmetic/test_${test}.v

                    vvp build/$test.out > logs/${test}.log

                    if grep -q "FAIL" logs/${test}.log
                    then
                        echo "Test $test failed."
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
}