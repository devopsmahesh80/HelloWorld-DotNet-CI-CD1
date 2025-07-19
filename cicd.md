# CI/CD Pipeline for .NET Web API with Docker, Terraform & Jenkins

This guide provides a comprehensive, step-by-step walkthrough for building a professional, end-to-end CI/CD pipeline for a .NET Web API. We will leverage an existing EC2 instance for Jenkins, use Docker to containerize the application, Terraform to provision the *application deployment* infrastructure on AWS, and Jenkins to automate the entire build, test, and deployment process.

## Table of Contents

- [CI/CD Pipeline for .NET Web API with Docker, Terraform \& Jenkins](#cicd-pipeline-for-net-web-api-with-docker-terraform--jenkins)
  - [Table of Contents](#table-of-contents)
  - [Prerequisites](#prerequisites)
  - [Step 1: Prepare Your EC2 Instance for Jenkins](#step-1-prepare-your-ec2-instance-for-jenkins)
  - [Step 2: Install Jenkins](#step-2-install-jenkins)
  - [Step 3: Create the .NET Application and Tests (Local)](#step-3-create-the-net-application-and-tests-local)
  - [Step 4: Containerize the Application with Docker (Local)](#step-4-containerize-the-application-with-docker-local)
  - [Step 5: Define Infrastructure with Terraform (Local)](#step-5-define-infrastructure-with-terraform-local)
  - [Step 6: Create the Jenkins CI/CD Pipeline (Jenkinsfile)](#step-6-create-the-jenkins-cicd-pipeline-jenkinsfile)
  - [Step 7: Configure Jenkins Credentials](#step-7-configure-jenkins-credentials)
  - [Step 8: Create the Jenkins Job](#step-8-create-the-jenkins-job)
  - [Step 9: Push Your Code to GitHub and Run the Pipeline](#step-9-push-your-code-to-github-and-run-the-pipeline)

## Prerequisites

Before you begin, ensure you have the following accounts and tools set up:

* **Your EC2 Instance for Jenkins:** An Amazon Linux 2023 or Ubuntu EC2 instance is recommended.
    * **Security Group:** Ensure its security group allows:
        * **SSH (Port 22):** From your IP address or a known range.
        * **HTTP (Port 8080):** For Jenkins (from your IP or wider for testing).
        * **HTTP (Port 80):** For your .NET application (from `0.0.0.0/0` for public access).
* **SSH Client:** To connect to your EC2 instance (e.g., PuTTY on Windows, `ssh` command on Linux/macOS).
* **Git:** Installed on your local machine for version control.
* **GitHub Account:** And a repository where you'll push your .NET application code.
* **Docker Hub Account:** To host your container images.
* **.NET 8 SDK & Docker Desktop (Local):** For developing and testing your application locally before pushing to Git.
* **AWS Account:** With an IAM user configured with programmatic access (access key and secret key). **Important:** If your Jenkins EC2 instance does not have an IAM role for AWS access, you will need to configure AWS credentials directly in Jenkins for Terraform.

## Step 1: Prepare Your EC2 Instance for Jenkins

Connect to your manually created EC2 instance and install the necessary software.

1.  **SSH into your EC2 Instance:**
    ```bash
    ssh -i /path/to/your/key.pem ec2-user@YOUR_EC2_PUBLIC_IP
    ```
    *(Replace `/path/to/your/key.pem` and `YOUR_EC2_PUBLIC_IP` with your actual values. If using Ubuntu, the default user might be `ubuntu`.)*

2.  **Update System Packages:**
    ```bash
    sudo yum update -y # For Amazon Linux / CentOS
    # OR
    sudo apt update -y && sudo apt upgrade -y # For Ubuntu / Debian
    ```

3.  **Install Java (Jenkins Prerequisite - OpenJDK 17):**
    * **For Amazon Linux 2023:**
        ```bash
        sudo yum install -y java-17-amazon-corretto-devel
        ```
    * **For Ubuntu:**
        ```bash
        sudo apt install -y openjdk-17-jdk
        ```
    Verify Java installation:
    ```bash
    java -version
    ```

4.  **Install Git:**
    * **For Amazon Linux 2023:**
        ```bash
        sudo yum install -y git
        ```
    * **For Ubuntu:**
        ```bash
        sudo apt install -y git
        ```
    Verify Git installation:
    ```bash
    git --version
    ```

5.  **Install Docker:**
    * **For Amazon Linux 2023:**
        ```bash
        sudo yum install -y docker
        sudo systemctl start docker
        sudo systemctl enable docker
        ```
    * **For Ubuntu:**
        ```bash
        sudo apt install -y docker.io
        sudo systemctl start docker
        sudo systemctl enable docker
        ```
    Verify Docker installation:
    ```bash
    docker --version
    ```

6.  **Add `ec2-user` to Docker Group:** This allows the `ec2-user` (and Jenkins if it runs as this user or in its context) to execute Docker commands without `sudo`. **You must log out and log back in for this to take effect.**
    ```bash
    sudo usermod -a -G docker ec2-user
    ```
    **After running the above command, type `exit` to log out of SSH, and then SSH back in!**

7.  **Install Terraform CLI:**
    * **For Amazon Linux 2023 / Ubuntu (common method):**
        ```bash
        sudo yum install -y yum-utils # For Amazon Linux
        # For Ubuntu: sudo apt install -y gnupg software-properties-common curl

        # Add HashiCorp GPG key
        curl -fsSL [https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.gpg](https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.gpg) | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
        # For Ubuntu: curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

        # Add HashiCorp repository
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] [https://rpm.releases.hashicorp.com/AmazonLinux](https://rpm.releases.hashicorp.com/AmazonLinux) stable main" | sudo tee /etc/yum.repos.d/hashicorp.repo
        # For Ubuntu: echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list 
        sudo yum update -y # For Amazon Linux
        # For Ubuntu: sudo apt update -y

        sudo yum install terraform -y # For Amazon Linux
        # For Ubuntu: sudo apt install terraform -y
        ```
    Verify Terraform installation:
    ```bash
    terraform --version
    ```

## Step 2: Install Jenkins

1.  **Import Jenkins GPG Key and Add Repository:**

    * **For Amazon Linux 2023:**
        ```bash
        sudo wget -O /etc/yum.repos.d/jenkins.repo [https://pkg.jenkins.io/redhat-stable/jenkins.repo](https://pkg.jenkins.io/redhat-stable/jenkins.repo)
        sudo rpm --import [https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key](https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key)
        sudo yum install -y jenkins
        ```
    * **For Ubuntu:**
        ```bash

        curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo gpg --dearmor -o /usr/share/keyrings/jenkins-archive-keyring.gpg

        echo "deb [signed-by=/usr/share/keyrings/jenkins-archive-keyring.gpg] https://pkg.jenkins.io/debian-stable binary/" | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
        
        sudo apt update -y
        sudo apt install -y jenkins
        ```

2.  **Start and Enable Jenkins:**
    ```bash
    sudo systemctl start jenkins
    sudo systemctl enable jenkins
    ```

3.  **Verify Jenkins Status:**
    ```bash
    sudo systemctl status jenkins
    ```
    You should see `active (running)`.

4.  **Access Jenkins for Initial Setup:**
    Open your web browser and navigate to `http://YOUR_EC2_PUBLIC_IP:8080`.

    * You'll be prompted to unlock Jenkins. Retrieve the initial admin password from your EC2 instance:
        ```bash
        sudo cat /var/lib/jenkins/secrets/initialAdminPassword
        ```
    * Copy the password and paste it into the Jenkins setup page.
    * Click **Install suggested plugins**.
    * Create your first admin user when prompted.
    * Click **Save and Finish**.
    * Click **Start using Jenkins**.

## Step 3: Create the .NET Application and Tests (Local)

Perform these steps on your **local machine**.

1.  **Initialize Projects:**
    ```bash
    # Create a new solution file
    dotnet new sln -n HelloWorldApp

    # Create the Web API project in a 'src' directory
    dotnet new webapi -n HelloWorld.Api -o src/HelloWorld.Api

    # Create an xUnit test project in a 'tests' directory
    dotnet new xunit -n HelloWorld.Api.Tests -o tests/HelloWorld.Api.Tests

    # Add both projects to the solution
    dotnet sln add src/HelloWorld.Api/HelloWorld.Api.csproj
    dotnet sln add tests/HelloWorld.Api.Tests/HelloWorld.Api.Tests.csproj

    # Add a reference from the test project to the API project
    dotnet add tests/HelloWorld.Api.Tests/HelloWorld.Api.Tests.csproj reference src/HelloWorld.Api/HelloWorld.Api.csproj
    ```

2.  **Create the API Controller:** Replace `WeatherForecastController.cs` with `GreetingController.cs`.
    **File: `src/HelloWorld.Api/Controllers/GreetingController.cs`**
    ```csharp
    using Microsoft.AspNetCore.Mvc;

    namespace HelloWorld.Api.Controllers;

    [ApiController]
    [Route("[controller]")]
    public class GreetingController : ControllerBase
    {
        [HttpGet]
        public IActionResult Get()
        {
            return Ok(new { message = "Hello, World from an automated pipeline!" });
        }
    }
    ```

3.  **Write the Unit Test:** Replace `UnitTest1.cs` with `GreetingControllerTests.cs`.
    **File: `tests/HelloWorld.Api.Tests/GreetingControllerTests.cs`**
    ```csharp
    using Xunit;
    using HelloWorld.Api.Controllers;
    using Microsoft.AspNetCore.Mvc;

    public class GreetingControllerTests
    {
        [Fact]
        public void Get_ReturnsOkObjectResult_WithCorrectMessage()
        {
            // Arrange
            var controller = new GreetingController();

            // Act
            var result = controller.Get();

            // Assert
            var okResult = Assert.IsType<OkObjectResult>(result);
            var value = okResult.Value;
            Assert.NotNull(value);

            var messageProperty = value.GetType().GetProperty("message");
            Assert.NotNull(messageProperty);

            var message = messageProperty.GetValue(value, null) as string;
            Assert.Equal("Hello, World from an automated pipeline!", message);
        }
    }
    ```

## Step 4: Containerize the Application with Docker (Local)

Create a `Dockerfile` in the root directory of your project (on your **local machine**).

**File: `Dockerfile`**
```dockerfile
# Stage 1: Build the application
# Use the .NET SDK image to build the project
FROM [mcr.microsoft.com/dotnet/sdk:8.0](https://mcr.microsoft.com/dotnet/sdk:8.0) AS build
WORKDIR /app

# Copy solution and project files to restore dependencies
COPY *.sln .
COPY src/HelloWorld.Api/*.csproj ./src/HelloWorld.Api/
COPY tests/HelloWorld.Api.Tests/*.csproj ./tests/HelloWorld.Api.Tests/

# Restore dependencies for all projects
RUN dotnet restore

# Copy the rest of the source code
COPY . .

# Run tests as part of the build process
RUN dotnet test

# Publish the application, creating a release build
RUN dotnet publish src/HelloWorld.Api/HelloWorld.Api.csproj -c Release -o /app/out

# Stage 2: Create the final runtime image
# Use the smaller ASP.NET runtime image for efficiency
FROM [mcr.microsoft.com/dotnet/aspnet:8.0](https://mcr.microsoft.com/dotnet/aspnet:8.0) AS runtime
WORKDIR /app

# Copy the published output from the build stage
COPY --from=build /app/out .

# Expose the port the app will run on inside the container
EXPOSE 8080

# Define the entry point for the container
ENTRYPOINT ["dotnet", "HelloWorld.Api.dll"]
```
## Step 5: Define Infrastructure with Terraform (Local)
Create your Terraform files in the root directory of your project (on your local machine). These files will define the EC2 instance for your application deployment.

File: main.tf

Terraform
```
provider "aws" {
  region = var.aws_region
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

resource "aws_security_group" "dotnet_app_sg" {
  name        = "dotnet-app-sg"
  description = "Allow HTTP and SSH traffic to .NET app"
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow HTTP from anywhere
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.my_ip}/32"] # Allow SSH only from your IP
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "DotNetApp-SecurityGroup"
  }
}

resource "aws_instance" "app_server" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  key_name               = var.key_pair_name # Ensure this key pair exists in your AWS account
  vpc_security_group_ids = [aws_security_group.dotnet_app_sg.id]
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y docker git
              service docker start
              usermod -a -G docker ec2-user # Add ec2-user to docker group
              EOF
  tags = {
    Name = "DotNet-App-Server"
  }
}
```
File: variables.tf

Terraform
```
variable "aws_region" {
  description = "The AWS region to create resources in."
  default     = "us-east-1" # Or your preferred region
}

variable "my_ip" {
  description = "Your public IP address for SSH access to the app server."
  type        = string
}

variable "key_pair_name" {
  description = "The name of your AWS EC2 Key Pair for SSH access to the app server."
  type        = string
}
File: outputs.tf

Terraform

output "instance_public_ip" {
  description = "The public IP address of the EC2 instance for the .NET app."
  value       = aws_instance.app_server.public_ip
}
```
Note: You do not run terraform apply locally. Jenkins will execute these commands.

## Step 6: Create the Jenkins CI/CD Pipeline (Jenkinsfile)
Create this Jenkinsfile in the root directory of your project (on your local machine).

File: Jenkinsfile

Groovy
```
pipeline {
    agent any

    environment {
        // Docker Hub Credentials ID configured in Jenkins
        DOCKERHUB_CREDENTIALS_ID = 'dockerhub-credentials'
        DOCKERHUB_USERNAME       = 'your-dockerhub-username' // <-- CHANGE THIS to your Docker Hub username

        // EC2 SSH Key for deploying to the application server (the one Terraform creates)
        // This credential must be the .pem file content for your EC2 key pair (e.g., my-key.pem)
        EC2_SSH_KEY_ID           = 'cicddemo1' // ID of the SSH Key credential in Jenkins

        // Terraform variables - these will be passed to Terraform to create the application EC2
        // Find your current public IP (e.g., using 'whatismyip.com' or 'curl ifconfig.me')
        // This IP is for the security group's SSH access to the *application EC2*.
        TERRAFORM_MY_IP          = 'YOUR_PUBLIC_IP_FOR_SSH_TO_APP_EC2' // e.g., "103.1.2.3"
        // This is the name of the EC2 Key Pair *in AWS* that Terraform will associate with the *application EC2*.
        // It should match the key you set up in your 'variables.tf'.
        TERRAFORM_KEY_PAIR_NAME  = 'your-ec2-keypair-name-for-app-server' // e.g., "my-app-key"

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
                    echo 'Initializing Terraform...'
                    // Ensure Terraform CLI is installed on the Jenkins EC2 instance.
                    // AWS credentials for Terraform should be configured on the Jenkins EC2 instance
                    // (e.g., via IAM role attached to Jenkins EC2, or AWS CLI config).
                    sh 'terraform init'

                    echo 'Applying Terraform configuration to provision application EC2...'
                    // -auto-approve is for automation, use with caution in production.
                    // The variables passed here correspond to 'variables.tf'
                    def terraformOutput = sh(script: "terraform apply -auto-approve -input=false -var='my_ip=${TERRAFORM_MY_IP}' -var='key_pair_name=${TERRAFORM_KEY_PAIR_NAME}'", returnStdout: true)
                    echo "Terraform apply output: ${terraformOutput}"

                    // Extract the public IP of the newly created application EC2 instance
                    EC2_HOST = sh(script: "terraform output -raw instance_public_ip", returnStdout: true).trim()
                    echo "Provisioned Application EC2 Public IP: ${EC2_HOST}"
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
```
## Step 7: Configure Jenkins Credentials
On your Jenkins UI (http://YOUR_EC2_PUBLIC_IP:8080):

Navigate to Manage Jenkins > Credentials > System > Global credentials (unrestricted).

Add Docker Hub Credentials:

Click Add Credentials.

Kind: Username with password

Scope: Global

Username: Your Docker Hub username.

Password: Your Docker Hub password.

ID: dockerhub-credentials (exactly as used in Jenkinsfile).

Description: Docker Hub Credentials

Click Create.

Add EC2 Application Server SSH Key:

Click Add Credentials.

Kind: SSH Username with private key

Scope: Global

ID: cicddemo1 (exactly as used in Jenkinsfile).

Description: SSH Key for .NET Application EC2

Username: ec2-user (This is the default username for Amazon Linux instances).

Private Key: Select Enter directly. Paste the entire content of your .pem file (e.g., my-app-key.pem) into the text area, including -----BEGIN RSA PRIVATE KEY----- and -----END RSA PRIVATE KEY-----.

Click Add.

AWS Credentials for Terraform (on Jenkins EC2):

Option A (Recommended for EC2-hosted Jenkins): IAM Role: If your Jenkins EC2 instance has an IAM role attached with sufficient permissions (e.g., AmazonEC2FullAccess for simplicity, or a more restrictive custom policy for production like ec2:RunInstances, ec2:CreateTags, ec2:AuthorizeSecurityGroupIngress, etc.), you do not need to add AWS credentials in Jenkins. Terraform will automatically use the instance's role.

Option B (If IAM Role is not possible/preferred): Jenkins Credentials:

Click Add Credentials.

Kind: AWS Credentials (You might need the AWS Credentials plugin installed in Jenkins if this option isn't visible).

Scope: Global

ID: aws-terraform-credentials (or a similar name, then update your Jenkinsfile if you decide to use withAWS block)

Access Key ID: Your AWS Access Key ID.

Secret Access Key: Your AWS Secret Access Key.

Click Create.

If you use this method, you'll need to uncomment the withAWS blocks in your Jenkinsfile around the terraform init and terraform apply commands, like this:

Groovy
```
stage('Provision Application Infrastructure (Terraform)') {
    steps {
        script {
            withAWS(credentials: 'aws-terraform-credentials', region: 'us-east-1') { // Replace 'us-east-1' with your desired region
                sh 'terraform init'
                def terraformOutput = sh(script: "terraform apply -auto-approve -input=false -var='my_ip=${TERRAFORM_MY_IP}' -var='key_pair_name=${TERRAFORM_KEY_PAIR_NAME}'", returnStdout: true)
                // ... rest of the stage
            }
        }
    }
}
```
## Step 8: Create the Jenkins Job
On the Jenkins dashboard, click New Item.

Enter an Item name (e.g., HelloWorld-DotNet-CI-CD).

Select Pipeline.

Click OK.

On the job configuration page, scroll down to the Pipeline section.

For Definition, choose Pipeline script from SCM.

For SCM, choose Git.

Repository URL: Paste the HTTPS or SSH URL of your GitHub repository (e.g., https://github.com/your-username/HelloWorldApp.git).

Credentials: If your GitHub repository is private, you'll need to add Jenkins credentials for GitHub (e.g., Username with password/token or SSH Private Key). If it's public, you can leave this blank.

Branches to build: Set this to */main (or */master if that's your default branch).

Script Path: Ensure this is set to Jenkinsfile (the default).

Click Save.

## Step 9: Push Your Code to GitHub and Run the Pipeline
Perform these steps on your local machine.

Initialize Git in your project directory (if not already done):
```
Bash

cd /path/to/your/HelloWorldApp
git init
Add all files to Git:

Bash

git add .
Commit your changes:

Bash

git commit -m "Initial commit: .NET app, Dockerfile, Terraform, Jenkinsfile"
Add your GitHub repository as a remote:

Bash

git remote add origin [https://github.com/your-username/HelloWorldApp.git](https://github.com/your-username/HelloWorldApp.git)
(Replace https://github.com/your-username/HelloWorldApp.git with your actual repository URL.)

Push your code to GitHub:

Bash

git push -u origin main # Or 'master' if that's your branch name
```
Trigger the Jenkins Pipeline:

Go back to your Jenkins UI.

Navigate to your HelloWorld-DotNet-CI-CD job.

Click Build Now (or wait for the SCM polling to trigger if configured).

**Monitor and Verify:**

Watch the Console Output of the running build in Jenkins. You should see logs for:

Git Checkout

Terraform init and apply (look for the public IP output).

.NET restore, build, and test.

Docker image build and push.

SSH connection to the newly provisioned application EC2 and Docker commands running there.

Once the build is successful, copy the Application EC2 Public IP from the Jenkins console output.

Open a browser and navigate to http://<Application_EC2_Public_IP>/greeting. You should see the message: "Hello, World from an automated pipeline!"

**Congratulations!** You have successfully set up a full CI/CD pipeline, provisioning infrastructure for your application with Terraform, building and containerizing your .NET app with Docker, and orchestrating it all with Jenkins and GitHub, all running from your dedicated Jenkins EC2 instance.