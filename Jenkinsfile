pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    environment {
        IMAGE_NAME = 'saravanan6221/jenkins-flask-app'
        EC2_HOST = '34.232.46.30'
        EC2_USER = 'ubuntu'
        APP_HOST_PORT = '80'
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build') {
            steps {
                sh 'python3 -m venv .venv'
                sh '. .venv/bin/activate && pip install -r requirements.txt'
            }
        }

        stage('Test') {
            steps {
                sh '. .venv/bin/activate && pytest -v'
            }
        }

        stage('Docker Image Build') {
            steps {
                sh '''
                docker build \
                  --build-arg APP_VERSION=${BUILD_NUMBER} \
                  -t ${IMAGE_NAME}:${BUILD_NUMBER} \
                  -t ${IMAGE_NAME}:latest .
                '''
            }
        }

        stage('Docker Image Push') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'dockerhub-creds',
                        usernameVariable: 'DH_USER',
                        passwordVariable: 'DH_TOKEN'
                    )
                ]) {
                    sh '''
                    set +x
                    printf '%s' "$DH_TOKEN" |
                    docker login -u "$DH_USER" --password-stdin

                    docker push ${IMAGE_NAME}:${BUILD_NUMBER}
                    docker push ${IMAGE_NAME}:latest

                    docker logout
                    '''
                }
            }
        }

        stage('Deploy to EC2') {
            steps {
                sshagent(credentials: ['app-server-ssh']) {
                    sh '''
                    scp -o StrictHostKeyChecking=accept-new \
                    scripts/deploy_remote.sh \
                    ${EC2_USER}@${EC2_HOST}:/tmp/deploy_remote.sh

                    ssh -o StrictHostKeyChecking=accept-new \
                    ${EC2_USER}@${EC2_HOST} \
                    "chmod +x /tmp/deploy_remote.sh &&
                    APP_HOST_PORT=${APP_HOST_PORT} \
                    /tmp/deploy_remote.sh ${IMAGE_NAME}:${BUILD_NUMBER}"
                    '''
                }
            }
        }

        stage('Deployment Verification') {
            steps {
                sh '''
                for i in $(seq 1 15); do

                    if curl --fail --silent \
                    http://${EC2_HOST}/health; then

                        echo "Application is healthy"
                        exit 0
                    fi

                    sleep 4
                done

                echo "Health check failed"
                exit 1
                '''
            }
        }
    }

    post {
        success {
            echo 'CI/CD deployment successful'
        }

        failure {
            echo 'CI/CD pipeline failed'
        }

        always {
            echo 'Pipeline execution completed'
        }
    }
}
