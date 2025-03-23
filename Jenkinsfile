pipeline {
    agent any

    environment {
        SONAR_HOST_URL = 'http://localhost:9001'
        SCANNER_HOME = tool 'SonarScanner'
        SEMGREP_APP_TOKEN = credentials('SEMGREP_APP_TOKEN')
        SEMGREP_PR_ID = "${env.CHANGE_ID}"
        APPLICATION_URL = 'http://192.168.49.2:32735'
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
                    junit '**/target/surefire-reports/*.xml'
                    jacoco execPattern: '**/target/jacoco.exec'
                }
            }
        }

        stage('SAST') {
            parallel {
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

                stage('Semgrep Scan') {
                    steps {
                        script { 
                            def workspace = pwd()
                            sh """
                                docker run --rm \
                                    -e SEMGREP_APP_TOKEN=$SEMGREP_APP_TOKEN \
                                    -v "${workspace}:/semgrep" \
                                    --workdir /semgrep \
                                    returntocorp/semgrep semgrep scan \
                                    --config=p/owasp-top-ten \
                                    --config=p/r2c-security-audit \
                                    --config=p/secure-defaults \
                                    --config=p/java \
                                    --output semgrep-report.json \
                                    /semgrep/src/main
                            """
                            archiveArtifacts artifacts: 'semgrep-report.json', allowEmptyArchive: true
                        }
                    }
                }
            }
        }

        stage('SCA') {
            parallel {
                stage('Trivy FileSystem Scan') {
                    steps {
                        script {
                            try {
                                sh 'trivy fs --java-db-repository hub.docker.com/r/aquasec/trivy-java-db --severity HIGH,CRITICAL --format table -o trivy-fs-report.txt .'
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

        stage('OPA') {
            parallel {
                stage('Docker Conftest') {
                    steps {
                        script {
                            def workspace = pwd()
                            def status = sh(script: """
                            docker run --rm -v ${workspace}:/project openpolicyagent/conftest test \
                            /project/Dockerfile \
                            --policy /project/OPA-Docker-Security.rego \
                            --output json \
                            --strict > docker-conftest-report.json
                            """, returnStatus: true)
                            if (status != 0) {
                                error "Docker Conftest failed. Check docker-conftest-report.json for details."
                            }
                        }
                    }
                }

                stage('K8S Conftest') {
                    steps {
                        script {
                            def workspace = pwd()
                            def status = sh(script: """
                            docker run --rm -v ${workspace}:/project openpolicyagent/conftest test \
                            /project/k8s_deployment_service.yaml \
                            --policy /project/OPA-K8s-Security.rego \
                            --output json \
                            --strict > K8S-conftest-report.json
                            """, returnStatus: true)
                            if (status != 0) {
                                error "Kubernetes Conftest failed. Check K8S-conftest-report.json for details."
                            }
                        }
                    }
                }
            }
        }

        // Scan local YAML file wiht Docker kubesec
        stage('Kubesec Scan Local YAML') {
            steps {
                script {
                    def workspace = pwd()
                    def status = sh(script: """
                        docker run --rm -v ${workspace}:/kubesec kubesec/kubesec:v2 scan /kubesec/k8s_deployment_service.yaml > kscan-result.json 2>&1
                        cat kscan-result.json
                    """, returnStatus: true)
                    
                    archiveArtifacts artifacts: 'kscan-result.json', allowEmptyArchive: true
                    
                    if (status == 2) {
                        def report = readFile('kscan-result.json')
                        if (report.contains('"critical"')) {
                            error "Critical security issues found in k8s_deployment_service.yaml. Check kscan-result.json."
                        } else {
                            echo "No critical issues found, but some objects (e.g., Service) were not scanned. Proceeding."
                        }
                    } else if (status != 0) {
                        error "Kubesec scan failed with exit code ${status}."
                    }
                }
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

        stage('DAST Scan') {
            steps {
                script {
                    def workspace = pwd()
                    sh """
                        docker run --rm -v ${workspace}:/zap -t zaproxy/zap-stable zap-api-scan.py \
                            -t ${APPLICATION_URL}/v3/api-docs \
                            -f openapi \
                            -r zap-report.html
                    """
                    archiveArtifacts artifacts: 'zap-report.html', allowEmptyArchive: true
                    echo "OWASP ZAP report saved as zap-report.html."
                }
            }
        }

        // اضافه شده: اسکن منابع مستقر در خوشه با Kubesec
        stage('Kubesec Scan Deployed Resources') {
            steps {
                script {
                    withKubeConfig([credentialsId: 'kubeconfig']) {
                        sh """
                            kubectl get deployment devsecops -o yaml | docker run -i kubesec/kubesec:v2 scan /dev/stdin > kubesec-deployment.json
                            if grep -q '"critical"' kubesec-deployment.json; then
                                echo "Critical security issues found in deployed Deployment devsecops"
                                exit 1
                            fi
                        """
                        archiveArtifacts artifacts: 'kubesec-deployment.json', allowEmptyArchive: true
                    }
                }
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: '**/reports/dependency-check/*.xml, docker-conftest-report.json, K8S-conftest-report.json, semgrep-report.json, trivy-fs-report.txt, gitleaks-report.json, kubesec-reports/*.json, kubesec-deployment.json', allowEmptyArchive: true
            dependencyCheckPublisher(
                pattern: 'reports/dependency-check/dependency-check-report.xml',
                failedNewHigh: 1, 
                failedTotalCritical: 0, 
                stopBuild: true
            )
        }
    }
}