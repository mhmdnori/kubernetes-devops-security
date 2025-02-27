pipeline {
    agent any

    environment {
        SONAR_HOST_URL = 'http://localhost:9001'
        SCANNER_HOME = tool 'SonarScanner'
    }

    stages {
        stage('Checkout Source Code') {
            steps {
                git branch: 'main', url: 'https://github.com/mhmdnori/kubernetes-devops-security.git'
            }
        }

        stage('Build Artifact') {
            steps {
                sh "mvn clean package -DskipTests=true"
                archiveArtifacts 'target/*.jar'
            }
        }

        stage('Maven Test - JUnit and Jacoco') {
            steps {
                sh "mvn test"
            }
            post {
                always {
                    junit 'target/surefire-reports/*.xml'
                    jacoco execPattern: '**/target/jacoco.exec'
                }
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarScanner') {
                    sh """
                        $SCANNER_HOME \
                            -Dsonar.projectKey=devsecops-application \
                            -Dsonar.sources=src/main/java \
                            -Dsonar.java.binaries=target/classes \
                            -Dsonar.tests=src/test/java \
                            -Dsonar.java.test.binaries=target/test-classes \
                            -Dsonar.coverage.jacoco.xmlReportPaths=target/site/jacoco/jacoco.xml \
                            -Dsonar.host.url=$SONAR_HOST_URL
                    """
                }
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Download Trivy Database') {
            steps {
                script {
                    sh '''
                        export TRIVY_DB_REPOSITORY="ghcr.io/aquasecurity/trivy-db"
                        trivy image --download-db-only
                    '''
                }
            }
        }

        stage('Security Scans') {
            parallel {
                stage('Trivy FileSystem Scan') {
                    steps {
                        script {
                            try {
                                sh 'trivy fs --severity HIGH,CRITICAL,MEDIUM --format table -o trivy-fs-report.txt .'
                                archiveArtifacts artifacts: 'trivy-fs-report.txt', allowEmptyArchive: true

                                def reportContent = readFile('trivy-fs-report.txt')
                                if (reportContent.contains("CRITICAL") || reportContent.contains("HIGH")) {
                                    error "Critical or High severity vulnerabilities found in the filesystem scan. Aborting the pipeline!"
                                }
                            } catch (Exception e) {
                                echo "Trivy filesystem scan failed: ${e.getMessage()}"
                                currentBuild.result = 'FAILURE'
                                throw e
                            }
                        }
                    }
                }

                stage('Dependency-Check Analysis') {
                    steps {
                        dependencyCheck(
                            odcInstallation: 'Dependency-Check',
                            additionalArguments: '''
                                --noupdate
                                --project "my-project"
                                --scan . 
                                --out reports/dependency-check
                                --format XML 
                                --enableExperimental
                                --failOnCVSS 7
                                --data /var/lib/jenkins/dependency-check-data
                            ''',
                            nvdCredentialsId: 'nvd-api-key', 
                            stopBuild: true
                        )
                    }
                }
            }
        }

        stage('Publish Dependency-Check Results') {
            steps {
                dependencyCheckPublisher(
                    pattern: 'reports/dependency-check/dependency-check-report.xml',
                    failedNewHigh: 1, 
                    failedTotalCritical: 0, 
                    stopBuild: true
                )
            }
        }

        stage('Docker Build and Push') {
            steps {
                script {
                    def GIT_COMMIT = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
                    def IMAGE_TAG = "${GIT_COMMIT}-${BUILD_NUMBER}" 
                    
                    withDockerRegistry([credentialsId: "docker-hub", url: "https://index.docker.io/v1/"]) {
                        sh "echo 'Building image: mohammad9195/numeric-app:${IMAGE_TAG}'"
                        sh "docker build -t mohammad9195/numeric-app:${IMAGE_TAG} ."
                        sh "docker push mohammad9195/numeric-app:${IMAGE_TAG}"
                    }
                    sh "echo ${IMAGE_TAG} > image_tag.txt"
                    archiveArtifacts 'image_tag.txt'
                }
            }
        }

        stage('Kubernetes Deployment - DEV') {
            steps {
                script {
                    def IMAGE_TAG = readFile('image_tag.txt').trim()
                    sh "sed -i 's|replace|mohammad9195/numeric-app:${IMAGE_TAG}|g' k8s_deployment_service.yaml"
                    withKubeConfig([credentialsId: 'kubeconfig']) {
                        sh "kubectl apply -f k8s_deployment_service.yaml"
                        sh "kubectl rollout status deployment/numeric-app --timeout=300s"
                    }
                }
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: '**/reports/dependency-check/*.xml'
            junit '**/target/surefire-reports/*.xml'
        }
        failure {
            emailext(
                body: 'Pipeline Failed!',
                subject: 'Pipeline Status',
                recipientProviders: [[$class: 'CulpritsRecipientProvider'], [$class: 'DevelopersRecipientProvider']]
            )
        }
        success {
            emailext(
                body: 'Pipeline Succeeded!',
                subject: 'Pipeline Status',
                recipientProviders: [[$class: 'CulpritsRecipientProvider'], [$class: 'DevelopersRecipientProvider']]
            )
        }
    }
}
