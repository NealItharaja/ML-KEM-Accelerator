pipeline {
    agent {
        label 'linux'
    }

    environment {
        DESIGN_DIR = "src/ntt"
        TB_DIR = "testbench/ntt"
        TESTS = "ntt"
        SYNTH = "butterfly"
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

                for test in $TESTS
                do
                    echo "================================="
                    echo "Running $test"
                    echo "================================="

                    rm -f build/$test.out

                    iverilog \
                        -o build/$test.out \
                        ${DESIGN_DIR}/*.v src/memory/*.v src/arithmetic/*.v macros/*.v\
                        ${TB_DIR}/test_${test}.v

                    vvp build/$test.out > logs/${test}.log

                    if grep -q "FAIL" logs/${test}.log
                    then
                        echo "$test FAILED"
                        exit 1
                    fi
                done
                '''
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'logs/*.log',
                             fingerprint: true,
                             allowEmptyArchive: true
        }

        success {
            echo "All tests passed."
        }

        failure {
            echo "One or more tests failed."
        }
    }
}