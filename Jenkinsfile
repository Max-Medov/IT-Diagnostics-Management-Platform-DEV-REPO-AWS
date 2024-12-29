pipeline {
    agent any

    environment {
        REGISTRY = "docker.io"
        REGISTRY_CREDENTIALS = "dockerhub-credentials-id"
        DOCKER_ORG = "maxmedov"
        IMAGE_PREFIX = "it-diagnostics-management-platform"
        KUBE_NAMESPACE = "it-diagnostics"
        AWS_REGION = "us-east-1"
        CLUSTER_NAME = "eks-cluster-name"
        TEST_USER = "testuser"
        TEST_PASS = "testpass"
    }

    stages {
        // 1) Checkout main code
        stage('Checkout Application Code') {
            steps {
                git branch: 'main', url: 'https://github.com/Max-Medov/IT-Diagnostics-Management-Platform-AWS.git'
            }
        }

        // 2) Checkout dev repo for Kubernetes YAML
        stage('Checkout Kubernetes Configurations') {
            steps {
                dir('kubernetes-config') {
                    git branch: 'main', url: 'https://github.com/Max-Medov/IT-Diagnostics-Management-Platform-DEV-REPO-AWS.git'
                }
            }
        }

        // 3) Build Docker Images
        stage('Build Docker Images') {
            steps {
                script {
                    sh "docker build -t ${REGISTRY}/${DOCKER_ORG}/${IMAGE_PREFIX}:auth_service -f backend/auth_service/Dockerfile backend"
                    sh "docker build -t ${REGISTRY}/${DOCKER_ORG}/${IMAGE_PREFIX}:case_service -f backend/case_service/Dockerfile backend"
                    sh "docker build -t ${REGISTRY}/${DOCKER_ORG}/${IMAGE_PREFIX}:diagnostic_service -f backend/diagnostic_service/Dockerfile backend"
                    sh "docker build -t ${REGISTRY}/${DOCKER_ORG}/${IMAGE_PREFIX}:frontend -f frontend/Dockerfile frontend"
                }
            }
        }

        // 4) Pre-Push Minimal Sanity Tests
        stage('Pre-Push Minimal Sanity Tests') {
            steps {
                script {
                    def services = ['auth_service', 'case_service', 'diagnostic_service', 'frontend']
                    for (service in services) {
                        echo "Running sanity test for ${service}"
                        sh """
                            docker run -d --name test_${service} ${REGISTRY}/${DOCKER_ORG}/${IMAGE_PREFIX}:${service}
                            sleep 10
                        """
                        def running = sh(script: """
                            docker ps --filter name=test_${service} --filter status=running | grep test_${service} || true
                        """, returnStatus: true)
                        if (running != 0) {
                            sh "docker rm -f test_${service}"
                            error("Pre-push sanity test failed for ${service}")
                        } else {
                            sh "docker rm -f test_${service}"
                        }
                    }
                }
            }
        }

        // 5) Push Docker Images
        stage('Push Images to Docker Hub') {
            steps {
                withCredentials([usernamePassword(credentialsId: "${REGISTRY_CREDENTIALS}", usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    sh """
                        echo ${DOCKER_PASS} | docker login ${REGISTRY} -u ${DOCKER_USER} --password-stdin
                        docker push ${REGISTRY}/${DOCKER_ORG}/${IMAGE_PREFIX}:auth_service
                        docker push ${REGISTRY}/${DOCKER_ORG}/${IMAGE_PREFIX}:case_service
                        docker push ${REGISTRY}/${DOCKER_ORG}/${IMAGE_PREFIX}:diagnostic_service
                        docker push ${REGISTRY}/${DOCKER_ORG}/${IMAGE_PREFIX}:frontend
                    """
                }
            }
        }

        // 6) Apply Terraform Configuration
        stage('Apply Terraform') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-credentials-id',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    dir('terraform-aws-infra') {
                        sh """
                            terraform init
                            terraform plan -out=tfplan
                            terraform apply -auto-approve tfplan
                        """
                    }
                }
            }
        }

        // 7) Fetch ALB DNS Name
        stage('Fetch ALB DNS Name') {
            steps {
                script {
                    def alb_dns = sh(script: "kubectl get ingress -n ${KUBE_NAMESPACE} -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'", returnStdout: true).trim()

                    echo "ALB DNS Name: ${alb_dns}"

                    writeFile file: '.env', text: """
                        REACT_APP_AUTH_SERVICE_URL=http://${alb_dns}/auth
                        REACT_APP_CASE_SERVICE_URL=http://${alb_dns}/case
                        REACT_APP_DIAGNOSTIC_SERVICE_URL=http://${alb_dns}/diagnostic
                    """
                }
            }
        }

        // 8) Deploy to Kubernetes
        stage('Deploy to Kubernetes') {
            steps {
                sh """
                    kubectl apply -f secrets-configmap.yaml
                    kubectl apply -f postgres.yaml
                    kubectl apply -f auth-service.yaml
                    kubectl apply -f case-service.yaml
                    kubectl apply -f diagnostic-service.yaml
                    kubectl apply -f frontend.yaml
                    kubectl apply -f ingress.yaml
                    kubectl apply -f prometheus-rbac.yaml
                    kubectl apply -f prometheus-k8s.yaml
                    kubectl apply -f grafana-dashboard-provider.yaml
                    kubectl apply -f grafana-dashboard-configmap.yaml
                    kubectl apply -f datasources.yaml
                    kubectl apply -f grafana.yaml
                """
            }
        }

        // 9) Wait for Pods
        stage('Wait for Pods') {
            steps {
                script {
                    sh """
                        kubectl rollout status deployment/auth-service -n ${KUBE_NAMESPACE} --timeout=300s
                        kubectl rollout status deployment/case-service -n ${KUBE_NAMESPACE} --timeout=300s
                        kubectl rollout status deployment/diagnostic-service -n ${KUBE_NAMESPACE} --timeout=300s
                        kubectl rollout status deployment/frontend -n ${KUBE_NAMESPACE} --timeout=300s
                        kubectl rollout status deployment/prometheus -n ${KUBE_NAMESPACE} --timeout=300s
                        kubectl rollout status deployment/grafana -n ${KUBE_NAMESPACE} --timeout=300s
                    """
                }
            }
        }

        // 10) Integration Tests
        stage('Integration Tests') {
            steps {
                script {
                    def alb_dns = sh(script: "kubectl get ingress -n ${KUBE_NAMESPACE} -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'", returnStdout: true).trim()
                    echo "Testing against ALB DNS: ${alb_dns}"

                    sh """
                        curl -I http://${alb_dns}/auth
                        curl -I http://${alb_dns}/case
                        curl -I http://${alb_dns}/diagnostic
                    """
                }
            }
        }
    }

    post {
        success {
            echo 'Pipeline completed successfully!'
        }
        failure {
            echo 'Some stage failed. Check logs.'
        }
        always {
            cleanWs()
        }
    }
}

