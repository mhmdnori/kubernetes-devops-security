pipeline {
  agent any

  stages {
    stage('Clean Workspace') {
      steps {
        cleanWs()
      }
    }
    
    stage('Checkout SCM') {
      steps {
        checkout scm
      }
    }

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
    
    stage('Docker Build and push') {
      steps {
        withDockerRegistry([credentialsId: "docker-hub", url: "https://index.docker.io/v1/"]) {
          sh "docker build -t mohammad9195/numeric-app ." 
          sh "docker push mohammad9195/numeric-app" 
        }
      }
    }
    
    stage('Kubernetes Deployment - DEV') {
      steps {
        sh "sed -i 's#replace#mohammad9195/numeric-app#g' k8s_deployment_service.yaml"
        withKubeConfig([credentialsId: 'kubeconfig']) {
          sh "kubectl apply -f k8s_deployment_service.yaml"
        }
      }
    }
  }
}
