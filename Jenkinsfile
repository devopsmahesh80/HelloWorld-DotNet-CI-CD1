pipeline {
    agent any

    environment {
        // Docker Hub Credentials ID configured in Jenkins
        DOCKERHUB_CREDENTIALS_ID = 'dockerhub-credentials'
        DOCKERHUB_USERNAME       = 'devopsmahesh80' // <-- CHANGE THIS to your Docker Hub username

        // EC2 SSH Key for deploying to the application server (the one Terraform creates)
        // This credential must be the .pem file content for your EC2 key pair (e.g., my-key.pem)
        EC2_SSH_KEY_ID           = 'cicddemo1' // ID of the SSH Key credential in Jenkins

        // Terraform variables - these will be passed to Terraform to create the application EC2
        // Find your current public IP (e.g., using 'whatismyip.com' or 'curl ifconfig.me')
        // This IP is for the security group's SSH access to the *application EC2*.
        TERRAFORM_MY_IP          = '172-31-16-38' // e.g., "103.1.2.3"
        // This is the name of the EC2 Key Pair *in AWS* that Terraform will associate with the *application EC2*.
        // It should match the key you set up in your 'variables.tf'.
        TERRAFORM_KEY_PAIR_NAME  = 'cicddemo1' // e.g., "my-app-key"

        // Placeholder for EC2_HOST, will be set by the Terraform stage after creation
        EC2_HOST                 = ''
    }

    stages {
        stage('Checkout') {
            steps {
                echo 'Checking out code from Git...'
                checkout scm // This checks out the code from your Git repository configured in the Jenkins job
            }
        }

        stage('Provision Application Infrastructure (Terraform)') {
            steps {
                script {
                    withAWS(credentials: 'aws-terraform-credentials', region: 'us-east-1') { // Replace 'us-east-1' with your desired region
                    sh 'terraform init'
                    def terraformOutput = sh(script: "terraform apply -auto-approve -input=false -var='my_ip=${TERRAFORM_MY_IP}' -var='key_pair_name=${TERRAFORM_KEY_PAIR_NAME}'", returnStdout: true)
            
                   }
                } 
            }
        }
        
        stage('Build & Test .NET Application') {
            // Use a Docker agent for .NET build to ensure consistent environment
            agent { docker { image '[mcr.microsoft.com/dotnet/sdk:8.0](https://mcr.microsoft.com/dotnet/sdk:8.0)' } }
            steps {
                echo 'Building and testing .NET application...'
                sh 'dotnet restore'
                sh 'dotnet build --configuration Release'
                sh 'dotnet test'
            }
        }

        stage('Build Docker Image') {
            steps {
                echo 'Building Docker image for the .NET application...'
                script {
                    // Builds the Docker image using the Dockerfile in the root
                    def dockerImage = docker.build("${env.DOCKERHUB_USERNAME}/helloworld-api:${env.BUILD_NUMBER}", '.')
                }
            }
        }

        stage('Push to Docker Hub') {
            steps {
                echo 'Pushing image to Docker Hub...'
                script {
                    // Authenticate with Docker Hub using Jenkins credentials
                    docker.withRegistry('[https://registry.hub.docker.com](https://registry.hub.docker.com)', env.DOCKERHUB_CREDENTIALS_ID) {
                        docker.image("${env.DOCKERHUB_USERNAME}/helloworld-api:${env.BUILD_NUMBER}").push()
                    }
                }
            }
        }

        stage('Deploy to Application EC2') {
            steps {
                echo "Deploying version ${env.BUILD_NUMBER} to Application EC2 host ${env.EC2_HOST}..."
                script {
                    // Basic check to ensure EC2_HOST was set by Terraform stage
                    if ("${env.EC2_HOST}" == '') {
                        error 'EC2_HOST variable is empty. Terraform stage might have failed or could not get the IP.'
                    }
                }
                // Use the SSH Agent plugin to securely connect to the application EC2
                sshagent(credentials: [env.EC2_SSH_KEY_ID]) {
                    sh '''
                        echo "Connecting to ec2-user@${EC2_HOST}..."
                        ssh -o StrictHostKeyChecking=no ec2-user@${EC2_HOST} << 'EOF'
                            echo "Logged into application EC2. Stopping/removing old container..."
                            docker stop helloworld-container || true
                            docker rm helloworld-container || true
                            echo "Pulling new Docker image: ${DOCKERHUB_USERNAME}/helloworld-api:${BUILD_NUMBER}"
                            docker pull ${DOCKERHUB_USERNAME}/helloworld-api:${BUILD_NUMBER}
                            echo "Running new container..."
                            docker run -d --name helloworld-container -p 80:8080 ${DOCKERHUB_USERNAME}/helloworld-api:${BUILD_NUMBER}
                            echo "Deployment complete on application EC2."
                        EOF
                    '''
                }
            }
        }
    }
    post {
        // This 'always' block runs after all stages, regardless of success or failure.
        // It's a good place for cleanup, but for infrastructure, be cautious.
        always {
            script {
                echo 'Pipeline finished. Consider if you need to destroy resources.'
                // Uncomment the following for automatic infrastructure destruction.
                // BE EXTREMELY CAREFUL WITH THIS IN PRODUCTION ENVIRONMENTS.
                // It will tear down the EC2 instance created by Terraform after every build!
                // sh 'terraform destroy -auto-approve -var="my_ip=${TERRAFORM_MY_IP}" -var="key_pair_name=${TERRAFORM_KEY_PAIR_NAME}"'
            }
        }
    }
}