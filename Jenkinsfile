pipeline {
    agent any

    environment {
        SONAR_HOST_URL = 'http://localhost:9001'
        SCANNER_HOME = tool 'SonarScanner'
    }

    stages {

        stage('Gitleaks Scan') {
            steps {
                script {
                    def workspace = pwd()
                    sh """
                    docker run --rm -v ${workspace}:/path zricethezav/gitleaks:latest detect \
                        --source="/path" \
                        --no-git \
                        --gitleaks-ignore-path="/path/.gitleaksignore" \
                        --report-format json \
                        --report-path="/path/gitleaks-report.json" \
                        --exit-code 0
                    """
                    archiveArtifacts artifacts: 'gitleaks-report.json', allowEmptyArchive: true
                    echo "Gitleaks Report:"
                    sh 'cat gitleaks-report.json || echo "Report not found"'
                }
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
                            -Dsonar.host.url=$SONAR_HOST_URL \
                            -Dsonar.java.coveragePlugin=jacoco
                    """
                }
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Security Scans') {
            parallel {
                stage('Trivy FileSystem Scan') {
                    steps {
                        script {
                            try {
                                sh 'trivy fs --db-repository hub.docker.com/r/aquasec/trivy-java-db --severity HIGH,CRITICAL --format table -o trivy-fs-report.txt .'
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

        stage('Build Artifact') {
            steps {
                sh "mvn clean package -DskipTests=true"
                archiveArtifacts 'target/*.jar'
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
                        sh "kubectl rollout status deployment/devsecops --timeout=300s"
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
    }
}
