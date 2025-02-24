pipeline {
  agent any

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
    
    stage('Docker Build and Push') {
      steps {
        script {
          def IMAGE_TAG = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
          withDockerRegistry([credentialsId: "docker-hub", url: "https://index.docker.io/v1/"]) {
            sh "docker build -t mohammad9195/numeric-app:${IMAGE_TAG} ."
            sh "docker push mohammad9195/numeric-app:${IMAGE_TAG}"
          }
          sh "echo IMAGE_TAG=${IMAGE_TAG} > image_tag.txt"
          archiveArtifacts 'image_tag.txt'
        }
      }
    }
    
    stage('Kubernetes Deployment - DEV') {
      steps {
        script {
          def IMAGE_TAG = readFile('image_tag.txt').trim()
          sh "sed -i 's#replace#mohammad9195/numeric-app:${IMAGE_TAG}#g' k8s_deployment_service.yaml"
          withKubeConfig([credentialsId: 'kubeconfig']) {
            sh "kubectl apply -f k8s_deployment_service.yaml"
            sh "kubectl rollout restart deployment numeric-app"
          }
        }
      }
    }
  }
}
