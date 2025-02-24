pipeline {
  agent any

  environment {
      SONAR_HOST_URL = 'http://localhost:9001'
      SCANNER_HOME='SonarScanner'
  }

  stages {
    stage('Build Artifact') {
      steps {
        sh "mvn clean package -DskipTests=true"
        archiveArtifacts 'target/*.jar'
      }
    }
    
    stage('Maven Test') {
      steps {
        sh "mvn test"
      }
    }

  stage('SonarQube Analysis') {
    steps {
        withSonarQubeEnv('SonarScanner') {
            withCredentials([string(credentialsId: 'SONARQUBE_TOKEN', variable: 'SONARQUBE_TOKEN')]) {
                script {
                    echo "Running SonarQube Analysis..."
                    sh '''
                    set +x
                    sonar-scanner \
                      -Dsonar.projectKey=devsecops-application \
                      -Dsonar.sources=. \
                      -Dsonar.host.url=$SONAR_HOST_URL \
                      -Dsonar.login=$SONARQUBE_TOKEN
                    '''
                }

                timeout(time: 2, unit: 'MINUTES') {
                    script {
                        waitForQualityGate abortPipeline: true
                    }
                }
            }
        }
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
}