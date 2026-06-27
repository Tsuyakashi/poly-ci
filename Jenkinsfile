pipeline {
    agent any

    environment {
        REGISTRY      = '192.168.56.10:5000/poly-ci'
        PRODUCTION_IP = '192.168.56.11'
        WATCHTOWER_TOKEN = credentials('watchtower-token')
    }

    stages {
        stage('Detect Changes') {
            steps {
                script {
                    def changed = sh(
                        script: "git diff --name-only HEAD~1 HEAD || git diff --name-only HEAD",
                        returnStdout: true
                    ).trim()
                    env.BUILD_PYTHON = changed.contains('python/') ? 'true' : 'false'
                    env.BUILD_GO     = changed.contains('go/')     ? 'true' : 'false'
                    env.BUILD_NODEJS = changed.contains('nodejs/') ? 'true' : 'false'
                }
            }
        }

        stage('Build') {
            parallel {
                stage('python') {
                    when { expression { env.BUILD_PYTHON == 'true' } }
                    steps {
                        sh '''
                            docker build -t $REGISTRY:python-latest ./python/
                            docker push $REGISTRY:python-latest
                        '''
                    }
                }
                stage('go') {
                    when { expression { env.BUILD_GO == 'true' } }
                    steps {
                        sh '''
                            docker build -t $REGISTRY:go-latest ./go/
                            docker push $REGISTRY:go-latest
                        '''
                    }
                }
                stage('nodejs') {
                    when { expression { env.BUILD_NODEJS == 'true' } }
                    steps {
                        sh '''
                            docker build -t $REGISTRY:nodejs-latest ./nodejs/
                            docker push $REGISTRY:nodejs-latest
                        '''
                    }
                }
            }
        }

        stage('Deploy') {
            when { branch 'main' }
            parallel {
                stage('deploy-python') {
                    when { expression { env.BUILD_PYTHON == 'true' } }
                    steps {
                        sh '''
                            curl -sf -H "Authorization: Bearer $WATCHTOWER_TOKEN" \
                                -X POST "http://$PRODUCTION_IP:8080/v1/update?container=python-app" || true
                        '''
                    }
                }
                stage('deploy-go') {
                    when { expression { env.BUILD_GO == 'true' } }
                    steps {
                        sh '''
                            curl -sf -H "Authorization: Bearer $WATCHTOWER_TOKEN" \
                                -X POST "http://$PRODUCTION_IP:8080/v1/update?container=go-app" || true
                        '''
                    }
                }
                stage('deploy-nodejs') {
                    when { expression { env.BUILD_NODEJS == 'true' } }
                    steps {
                        sh '''
                            curl -sf -H "Authorization: Bearer $WATCHTOWER_TOKEN" \
                                -X POST "http://$PRODUCTION_IP:8080/v1/update?container=nodejs-app" || true
                        '''
                    }
                }
            }
        }
    }
}
