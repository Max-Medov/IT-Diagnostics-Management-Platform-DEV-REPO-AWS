pipeline {

    agent any

    environment {
        REGISTRY = "docker.io"
        REGISTRY_CREDENTIALS = "dockerhub-credentials-id"
        DOCKER_ORG = "maxmedov"
        IMAGE_PREFIX = "it-diagnostics-management-platform"
        KUBE_NAMESPACE = "it-diagnostics"
        AWS_REGION = "us-east-1"
        CLUSTER_NAME = "eks-max-project"
        TEST_USER = "testuser"
        TEST_PASS = "testpass"
        S3_BUCKET = "max-terraform-state-bucket"
    }

    stages {

        // 1) Checkout dev repo for Kubernetes YAML
        stage('Checkout Kubernetes Configurations') {
            steps {
                dir('AWS-DEV') {
                    git branch: 'main', url: 'https://github.com/Max-Medov/IT-Diagnostics-Management-Platform-DEV-REPO-AWS.git'
                }
            }
        }

        // 2) Apply Terraform Configuration
        stage('Destroy Terraform') {
            steps {
                withCredentials([
                    aws(credentialsId: 'aws-credentials-id', accessKeyVariable: 'AWS_ACCESS_KEY_ID', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY')
                ]) {
                    dir('AWS-DEV/terraform/terraform-aws-infra') {
                        sh '''
                            terraform init
                            terraform destroy -auto-approve
                        '''
                    }
                }
            }
        }
    }

    post {
        success {
            echo 'Pipeline completed successfully!'
        }
        failure {
            echo 'Pipeline failed! Destroying all Terraform resources...'
            withCredentials([
                aws(credentialsId: 'aws-credentials-id', accessKeyVariable: 'AWS_ACCESS_KEY_ID', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY')
            ]) {
                dir('AWS-DEV/terraform/terraform-aws-infra') {
                    sh '''
                        terraform init
                        terraform destroy -auto-approve
                    '''
                }
            }
        }
        always {
            cleanWs()
        }
    }
}

