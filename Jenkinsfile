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

        // 1) Checkout main code
        stage('Checkout Application Code') {
            steps {
                git branch: 'main', url: 'https://github.com/Max-Medov/IT-Diagnostics-Management-Platform-AWS.git'
            }
        }

        // 2) Checkout dev repo for Kubernetes YAML
        stage('Checkout Kubernetes Configurations') {
            steps {
                dir('AWS-DEV') {
                    git branch: 'main', url: 'https://github.com/Max-Medov/IT-Diagnostics-Management-Platform-DEV-REPO-AWS.git'
                }
            }
        }

        // 3) Build Docker Images
        stage('Build Docker Images') {
            steps {
                script {
                    // Build auth_service
                    sh """
                      docker build -t ${REGISTRY}/${DOCKER_ORG}/${IMAGE_PREFIX}:auth_service \
                        -f backend/auth_service/Dockerfile backend
                    """

                    // Build case_service
                    sh """
                      docker build -t ${REGISTRY}/${DOCKER_ORG}/${IMAGE_PREFIX}:case_service \
                        -f backend/case_service/Dockerfile backend
                    """

                    // Build diagnostic_service
                    sh """
                      docker build -t ${REGISTRY}/${DOCKER_ORG}/${IMAGE_PREFIX}:diagnostic_service \
                        -f backend/diagnostic_service/Dockerfile backend
                    """

                    // Build frontend with path-based environment variables
                    sh """
                      docker build \
                        --build-arg REACT_APP_AUTH_SERVICE_URL=/auth \
                        --build-arg REACT_APP_CASE_SERVICE_URL=/case \
                        --build-arg REACT_APP_DIAGNOSTIC_SERVICE_URL=/diagnostic \
                        -t ${REGISTRY}/${DOCKER_ORG}/${IMAGE_PREFIX}:frontend \
                        -f frontend/Dockerfile frontend
                    """
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

        // 6) Setup S3 Backend Bucket (Terraform)
        stage('Setup Backend for Terraform') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-credentials-id',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    script {
                        sh """
                            if ! aws s3api head-bucket --bucket ${S3_BUCKET} 2>/dev/null; then
                                if [ \"${AWS_REGION}\" = \"us-east-1\" ]; then
                                    aws s3api create-bucket --bucket ${S3_BUCKET}
                                else
                                    aws s3api create-bucket --bucket ${S3_BUCKET} --region ${AWS_REGION} --create-bucket-configuration LocationConstraint=${AWS_REGION}
                                fi
                                # Enable versioning
                                aws s3api put-bucket-versioning --bucket ${S3_BUCKET} --versioning-configuration Status=Enabled
                                # Enable server-side encryption
                                aws s3api put-bucket-encryption --bucket ${S3_BUCKET} --server-side-encryption-configuration '{
                                    "Rules": [
                                        {
                                            "ApplyServerSideEncryptionByDefault": {
                                                "SSEAlgorithm": "AES256"
                                            }
                                        }
                                    ]
                                }'
                            fi
                        """
                    }
                }
            }
        }

        // 7) Apply Terraform Configuration
        stage('Apply Terraform') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-credentials-id',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    dir('AWS-DEV/terraform/terraform-aws-infra') {
                        sh """
                            terraform init
                            terraform plan -out=tfplan
                            terraform apply -auto-approve tfplan

                            aws eks --region ${AWS_REGION} update-kubeconfig --name ${CLUSTER_NAME}
                            kubectl cluster-info
                            kubectl get nodes
                        """
                    }
                }
            }
        }

        // 8) Deploy Kubernetes Resources
        stage('Deploy Kubernetes Resources') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-credentials-id',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    dir('AWS-DEV/kubernetes') {
                        sh """
                            kubectl apply -f namespace.yaml
                            kubectl apply -f secrets-configmap.yaml
                            kubectl apply -f postgres.yaml
                            kubectl apply -f auth-service.yaml
                            kubectl apply -f case-service.yaml
                            kubectl apply -f diagnostic-service.yaml
                            kubectl apply -f frontend.yaml
                            kubectl apply -f prometheus-rbac.yaml
                            kubectl apply -f prometheus-k8s.yaml
                            kubectl apply -f grafana-dashboard-provider.yaml
                            kubectl apply -f grafana-dashboard-configmap.yaml
                            kubectl apply -f datasources.yaml
                            kubectl apply -f grafana.yaml
                            kubectl apply -f ingress.yaml
                        """
                    }
                }
            }
        }

        // 9) Wait for Pods
        stage('Wait for Pods') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-credentials-id',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    script {
                        sh """
                            kubectl rollout status deployment/auth-service -n ${KUBE_NAMESPACE} --timeout=300s
                            kubectl rollout status deployment/case-service -n ${KUBE_NAMESPACE} --timeout=300s
                            kubectl rollout status deployment/diagnostic-service -n ${KUBE_NAMESPACE} --timeout=300s
                            kubectl rollout status deployment/frontend -n ${KUBE_NAMESPACE} --timeout=300s
                            kubectl rollout status deployment/grafana -n ${KUBE_NAMESPACE} --timeout=300s
                        """
                    }
                }
            }
        }

        // 10) Fetch ALB DNS Name
        stage('Fetch ALB DNS Name') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-credentials-id',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    script {
                        def alb_dns = ""
                        timeout(time: 300, unit: 'SECONDS') {
                            while (alb_dns == "") {
                                echo "Waiting for ALB DNS Name..."
                                sleep 10
                                try {
                                    alb_dns = sh(
                                        script: "kubectl get ingress -n ${KUBE_NAMESPACE} -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'",
                                        returnStdout: true
                                    ).trim()
                                } catch (Exception e) {
                                    echo "Failed to fetch ALB DNS, retrying..."
                                }
                            }
                        }
                        echo "ALB DNS Name: ${alb_dns}"
                        env.ALB_DNS = alb_dns
                    }
                }
            }
        }

        // NOTE: We REMOVE or COMMENT OUT the old "Rebuild Frontend with ALB DNS" stage:
        // stage('Rebuild Frontend with ALB DNS') { ... }

        // 11) Integration Tests (Now that ALB is available)
        stage('Integration Tests') {
            steps {
                script {
                    echo "Testing against ALB-based paths: http://${env.ALB_DNS}"
                    sh """
                        # 1) Attempt user registration
                        REGISTER_RESPONSE=\$(curl -s -o /dev/null -w "%{http_code}" -X POST -H 'Content-Type: application/json' \\
                          -d '{"username": "${TEST_USER}", "password": "${TEST_PASS}"}' http://${env.ALB_DNS}/auth/register)
                        if [ "\$REGISTER_RESPONSE" = "409" ]; then
                          echo "User already exists."
                        elif [ "\$REGISTER_RESPONSE" = "201" ]; then
                          echo "User newly registered."
                        else
                          echo "Registration failed with code \$REGISTER_RESPONSE"
                          exit 1
                        fi

                        # 2) Login to get token
                        TOKEN=\$(curl -s -f -X POST -H 'Content-Type: application/json' \\
                          -d '{"username": "${TEST_USER}", "password": "${TEST_PASS}"}' http://${env.ALB_DNS}/auth/login | jq -r '.access_token')
                        if [ -z "\$TOKEN" ] || [ "\$TOKEN" = "null" ]; then
                          echo "Login failed. No token returned."
                          exit 1
                        fi

                        # 3) Test case-service endpoint
                        curl -f -X POST -H 'Content-Type: application/json' -H "Authorization: Bearer \$TOKEN" \\
                          -d '{"description": "Integration Test Case", "platform": "Linux Machine"}' \\
                          http://${env.ALB_DNS}/case/cases || exit 1

                        # 4) Test diagnostic-service endpoint
                        curl -f -H "Authorization: Bearer \$TOKEN" http://${env.ALB_DNS}/diagnostic/download_script/1 || exit 1
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

