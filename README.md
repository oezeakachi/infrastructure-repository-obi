# GitOps ArgoCD Implementation: Automate Infrastructure Creation with Terraform & GitHub Actions, and Application Deployment on EKS Cluster

This guide provides a comprehensive walkthrough for setting up a GitOps workflow. It uses **Terraform** and **GitHub Actions** to automate infrastructure provisioning on **AWS EKS** and leverages **ArgoCD** for automating application deployments.

[![LinkedIn](https://img.shields.io/badge/Connect%20with%20me%20on-LinkedIn-blue.svg)](https://www.linkedin.com/in/mir-owahed-ali-8786a8153/)

[![YouTube](https://img.shields.io/badge/Subscribe%20to-YouTube-FF0000?style=for-the-badge&logo=youtube&logoColor=white)](https://www.youtube.com/channel/UCE0wN4DnpNaAQ7duTMpHJ5Q)


## **Table of Contents**

- [Overview](#overview)
- [Pre-requisites](#pre-requisites)
- [Step 1: Create GitHub Repositories](#step-1-create-github-repositories)
  - [1.1. Create Infrastructure Repository](#11-create-infrastructure-repository)
  - [1.2. Create Application Repository](#12-create-application-repository)
- [Step 2: Configure GitHub Secrets](#step-2-configure-github-secrets)
- [Step 3: Configure Terraform for EKS Setup](#step-3-configure-terraform-for-eks-setup)
  - [3.1. Create Terraform Files](#31-create-terraform-files)
  - [3.2. Initialize and Validate Infrastructure](#32-initialize-and-validate-infrastructure)
- [Step 4: Create GitHub Actions Workflow](#step-4-create-github-actions-workflow)
- [Step 5: Install ArgoCD on EKS Cluster](#step-5-install-argocd-on-eks-cluster)
- [Step 6: Access the ArgoCD UI](#step-6-access-the-argocd-ui)
- [Step 7: Configure ArgoCD for Automated Application Deployment](#step-7-configure-argocd-for-automated-application-deployment)

---

## **Overview**
This guide will help you set up an automated GitOps pipeline:
1. **Automate Infrastructure**: Use Terraform and GitHub Actions to provision an EKS cluster.
2. **Automate Application Deployment**: Use ArgoCD to monitor the application repository and deploy updates to the EKS cluster automatically.

---
## Watch the Tutorial

[![Automate EKS Infrastructure with Terraform & GitHub Actions | GitOps App Deployment with ArgoCD](https://img.youtube.com/vi/dy1CkxQv0SM/0.jpg)](https://youtu.be/dy1CkxQv0SM)

[Watch the full tutorial on YouTube](https://youtu.be/dy1CkxQv0SM) to follow along with step-by-step instructions.
---
## **Pre-requisites**
- **GitHub account** to create repositories.
- **AWS account** with permissions to create EKS resources.
- **AWS CLI** installed and configured on your local machine.
- **kubectl** installed for Kubernetes cluster management.
  
---

## **Step 1: Create GitHub Repositories**

### **1.1. Create Infrastructure Repository**
- Create a GitHub repository called `infrastructure` to store Terraform configurations.
- Initialize the repository with a `README.md` file.

### **1.2. Create Application Repository**
- Create a separate GitHub repository called `application` to store Kubernetes manifest files.
- Initialize the repository with a `README.md` file.

---

## **Step 2: Configure GitHub Secrets**

### **2.1. GitHub Secrets Setup**
To authenticate GitHub Actions with AWS for infrastructure deployment:
1. Go to your **Infrastructure Repository** in GitHub.
2. Navigate to `Settings > Secrets and variables > Actions`.
3. Add the following secrets:
   - **AWS_ACCESS_KEY_ID**
   - **AWS_SECRET_ACCESS_KEY**

These secrets are necessary for AWS authentication when GitHub Actions runs the Terraform configuration.

---

## **Step 3: Configure Terraform for EKS Setup**

### **3.1. Create Terraform Files**
In the `infrastructure` repository, create the following Terraform files:

#### **`main.tf`** (Terraform configuration for EKS)
```hcl
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  route {
    cidr_block = "10.0.0.0/16"
    gateway_id = "local"
  }
}

resource "aws_route_table_association" "subnet_1_association" {
  subnet_id      = aws_subnet.subnet_1.id
  route_table_id = aws_route_table.main.id
}

resource "aws_route_table_association" "subnet_2_association" {
  subnet_id      = aws_subnet.subnet_2.id
  route_table_id = aws_route_table.main.id
}

resource "aws_route_table_association" "subnet_3_association" {
  subnet_id      = aws_subnet.subnet_3.id
  route_table_id = aws_route_table.main.id
}

resource "aws_subnet" "subnet_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "subnet_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "subnet_3" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "ap-south-1c"
  map_public_ip_on_launch = true
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "my-cluster"
  cluster_version = "1.31"

  cluster_endpoint_public_access = true

  cluster_addons = {
    coredns                = {}
    eks-pod-identity-agent = {}
    kube-proxy             = {}
    vpc-cni                = {}
  }

  vpc_id                   = aws_vpc.main.id
  subnet_ids               = [aws_subnet.subnet_1.id, aws_subnet.subnet_2.id, aws_subnet.subnet_3.id]
  control_plane_subnet_ids = [aws_subnet.subnet_1.id, aws_subnet.subnet_2.id, aws_subnet.subnet_3.id]

  eks_managed_node_groups = {
    green = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["m5.xlarge"]

      min_size     = 1
      max_size     = 1
      desired_size = 1
    }
  }
}
```

#### **`provider.tf`** (Specifies the AWS provider)
```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-south-1"
}
```

#### **`backend.tf`** (Configure S3 backend for state management)
```hcl
terraform {
  backend "s3" {
    bucket = "mir-terraform-s3-bucket"
    key    = "key/terraform.tfstate"
    region = "ap-south-1"
  }
}
```

### **3.2. Initialize and Validate Infrastructure**
Push the code to your GitHub `infrastructure` repository:
```bash
git add .
git commit -m "Initial Terraform setup for EKS"
git push origin main
```

---

## **Step 4: Create GitHub Actions Workflow**

Create a GitHub Actions workflow file to automate Terraform deployment.

#### **`.github/workflows/terraform.yml`**
```yaml
name: Terraform CI/CD Pipeline

on:
  push:
    branches:
      - main
  pull_request:
    branches:
      - main

jobs:
  terraform:
    name: Apply Terraform
    runs-on: ubuntu-latest

    steps:
    - name: Checkout Code
      uses: actions/checkout@v2

    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v2
      with:
        terraform_version: 1.5.6

    - name: Configure AWS Credentials
      uses: aws-actions/configure-aws-credentials@v2
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: ${{ secrets.AWS_REGION }}

    - name: Terraform Init
      run: terraform init

    - name: Terraform Plan
      run: terraform plan

    - name: Terraform Apply
      if: github.ref == 'refs/heads/main'
      run: terraform apply -auto-approve
```

GitHub Actions will:
- Initialize Terraform.
- Plan the infrastructure.
- Apply changes to the `main` branch.

---

## **Step 5: Install ArgoCD on EKS Cluster**

1. **Configure `kubectl` to access your EKS cluster**:
   ```bash
   aws eks update-kubeconfig --region ap-south-1 --name my-cluster
   kubectl cluster-info
   kubectl get nodes
   ```
  
2. **Install ArgoCD**:
   ```bash
   kubectl create namespace argocd
   kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
   ```

3. **Change the ArgoCD server service type to LoadBalancer**:
   ```bash


   kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
   ```

4. **Retrieve Initial Admin Credentials**:
   ```bash
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
   ```

---

## **Step 6: Access the ArgoCD UI**

1. **Get the External IP of the ArgoCD server**:
   ```bash
   kubectl get svc argocd-server -n argocd
   ```

2. **Access the ArgoCD UI** by navigating to `http://<EXTERNAL-IP>` in your browser.
3. **Login to ArgoCD**:
   - **Username**: `admin`
   - **Password**: Retrieved from the previous step.

---

## **Step 7: Configure ArgoCD for Automated Application Deployment**

1. **Log in to ArgoCD UI**.
2. **Add a New Application**:
   - In ArgoCD UI, click on **New App**.
   - Fill in the following details:
     - **Application Name**: `my-app`
     - **Project**: `default`
     - **Sync Policy**: Automatic (if desired)
   - **Source**:
     - **Repository URL**: `https://github.com/your-username/application`
     - **Revision**: `main`
     - **Path**: `/` (or the relevant folder for manifests)
   - **Destination**:
     - **Cluster**: `https://kubernetes.default.svc`
     - **Namespace**: `default` (or any other)

3. **Save** the configuration. ArgoCD will now monitor the application repository for changes and deploy them automatically to the EKS cluster.

---

By following this guide, you now have a fully automated GitOps pipeline using **Terraform**, **GitHub Actions**, and **ArgoCD**. Your EKS infrastructure is provisioned, and application deployments are automated through ArgoCD.

## Prometheus Setup

```
Understanding the Prometheus Service URL
Based on the kubectl get service output you provided, the Prometheus server is exposed via a service named prometheus-server in the monitoring namespace on port 80.

The correct URL to use for the Prometheus data source in Grafana is:
http://prometheus-server.monitoring.svc.cluster.local

Here's how we construct that URL:

Service Name: The NAME of the service is prometheus-server.

Namespace: The command was run in the monitoring namespace.

Port: The PORT(S) column shows 80:31838/TCP, which means the service is listening on port 80.

The full internal DNS name for a Kubernetes service always follows the format:
http://<service-name>.<namespace>.svc.cluster.local:<port>

Putting these pieces together gives you the URL to connect Grafana to Prometheus within the cluster.

```

## Grafana SetUp
```
Why Is the "Data Sources" Section Empty?
The "Data Sources" section is empty because your Helm chart likely didn't automatically configure Prometheus. You'll need to manually add it so Grafana knows where to pull metrics from. This is a simple, one-time configuration.

How to Add the Prometheus Data Source
1. Get the Prometheus Service URL
You need to find the internal DNS name and port for your Prometheus server.
Run this command to find the service in the monitoring namespace:

kubectl get service -n monitoring

You'll see a list of services. Look for the Prometheus server service, which is usually named prometheus-server or prometheus. The CLUSTER-IP is the internal IP, and the PORT(S) column will show 9090 (the default Prometheus port).

The internal URL will follow this format: http://<service-name>.<namespace>.svc.cluster.local:<port>. For example: http://prometheus-server.monitoring.svc.cluster.local:9090.

2. Add the Data Source in Grafana

In Grafana, click the Gear icon (Configuration) on the left sidebar.

Select Data Sources.

Click the Add data source button.

In the list, select Prometheus.

3. Configure the Connection

Name: Give your data source a name, like Prometheus or EKS-Prometheus.

URL: Paste the internal URL you found in the previous step (e.g., http://prometheus-server.monitoring.svc.cluster.local:9090).

Leave all other settings at their defaults unless you have a specific reason to change them.

4. Save and Test
Click Save & Test.

If the connection is successful, you'll see a green "Data source is working" message. You can now go back to the dashboard import steps from my previous response. The new Prometheus data source will be available in the dropdown when you import a dashboard.
```

## Kubectl commands 
```
### Viewing Resources

# Get all pods in the current namespace
kubectl get pods

# Get all resources in all namespaces
kubectl get all --all-namespaces

# Get a specific deployment in a specific namespace
kubectl get deployment my-web-app -n my-namespace

# View resources with detailed output
kubectl get pods -o wide

# Describe a specific pod
kubectl describe pod my-web-app-pod

# Describe a specific service
kubectl describe service my-web-app-service

# Apply a deployment from a YAML file
kubectl apply -f my-deployment.yaml

# Create a new namespace
kubectl create namespace production

# Create a secret from literal values
kubectl create secret generic my-db-secret --from-literal=username=admin --from-literal=password=supersecret

# Delete a specific pod
kubectl delete pod my-app-pod

# Delete all resources defined in a YAML file
kubectl delete -f my-deployment.yaml

# Get logs from a pod
kubectl logs my-app-pod

# Stream logs in real-time
kubectl logs -f my-app-pod

# Open a bash shell in a pod
kubectl exec -it my-app-pod -- /bin/bash

# Run a single command inside a pod
kubectl exec my-app-pod -- ls -l /

# Forward local port 8080 to a pod's port 80
kubectl port-forward my-app-pod 8080:80

# View your current cluster context
kubectl config current-context

# List all available contexts
kubectl config get-contexts

# View CPU and memory usage of all nodes
kubectl top nodes

# View CPU and memory usage of all pods
kubectl top pods

# Delete a specific pod
kubectl delete pod <pod-name>

# Drain a node (safely removes all pods)
kubectl drain <node-name> --ignore-daemonsets

# Delete a namespace and all its resources
kubectl delete namespace <namespace-name>

# Manually log into a pod and open a shell
kubectl exec -it <pod-name> -- /bin/bash

# Log into a specific container within a multi-container pod
kubectl exec -it <pod-name> -c <container-name> -- /bin/bash

```

```
Your original error failed to provision volume with StorageClass "gp3" is a clear indication that the IAM role attached to your EKS nodes is missing a key permission. The "EC2 Linux" label is a red herring in this context, as it refers to a different mechanism for cluster authentication.

The most straightforward fix is to add the necessary permissions to the IAM role that your EKS worker nodes use. While IRSA is the best practice for application-specific permissions, fixing the node role is the direct solution for this specific volume provisioning failure.

Go to the AWS IAM console.

Find the role green-eks-node-group-...

Add a new policy or edit an existing one to include the ec2:CreateVolume, ec2:DescribeVolumes, and ec2:AttachVolume actions.

The Kubernetes controller will automatically retry provisioning the volume, and it should succeed after the permissions are in place. -> Edit the terraform code creating role to give ec2 policy that gives right create and delete volumes
```

```
## Add Admin access to user account so you add iam access entry to EKS cluster

Okay, I can definitely walk you through how to **temporarily grant** `**AdministratorAccess**` **to your Jenkins IAM role/user in the AWS Console.**  
**IMPORTANT SECURITY NOTE:** Attaching `AdministratorAccess` grants full permissions to your AWS account. This is **ONLY for debugging purposes** to confirm if your current issue is a permissions problem. **You MUST remove this policy immediately after you confirm the issue is resolved (or not resolved) and before any production deployment.**  
Here are the step-by-step instructions:  
**Step 1: Log in to the AWS Management Console**  

1. Open your web browser and go to [https://aws.amazon.com/console/](https://aws.amazon.com/console/).
2. Log in with your AWS account credentials that have sufficient permissions to modify IAM users/roles (often your root account or another administrator account).

**Step 2: Navigate to the IAM Service**  

1. In the AWS Management Console, use the search bar at the top and type `IAM`.
2. Select **IAM** from the services list.

**Step 3: Find the Jenkins IAM User or Role**  
You need to identify the specific IAM entity that your Jenkins pipeline is using to authenticate with AWS. This is the user or role whose `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` you have configured in Jenkins.  

1. On the left-hand navigation pane in IAM, click on either **Users** or **Roles**, depending on whether your Jenkins is configured with an IAM User or an IAM Role.
    - **Users:** If Jenkins uses an `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` directly for a specific IAM User.
    - **Roles:** If Jenkins is running on an EC2 instance with an Instance Profile attached (which is a best practice) or assuming a specific role using temporary credentials.
2. Search for the name of the IAM user or role that Jenkins uses. (e.g., `jenkins-user`, `jenkins-pipeline-role`, etc.).
3. Click on the name of the identified user or role to go to its summary page.

**Step 4: Attach the** `**AdministratorAccess**` **Policy**  

1. On the user/role's summary page, look for the **"Permissions"** tab.
2. Click on the **"Add permissions"** button (or "Attach policies directly" if it's a role and it appears).
3. On the "Add permissions" page, click on **"Attach policies directly"**.
4. In the search bar, type `AdministratorAccess`.
5. **Check the checkbox** next to `AdministratorAccess`.
6. Scroll down and click the **"Next"** button.
7. Review the changes on the "Review and add permissions" page.
8. Click **"Add permissions"** (or "Add policy" / "Attach policy").

**Step 5: Run Your Jenkins Pipeline Again**  

1. Go back to your Jenkins dashboard.
2. Trigger your pipeline build again.

**Step 6: IMPORTANT! Remove** `**AdministratorAccess**` **(Crucial After Testing)**  

- Regardless of whether your pipeline succeeded or failed, once you have completed this test, **you MUST remove the** `**AdministratorAccess**` **policy** from your Jenkins IAM user/role.
- Go back to the IAM user/role's summary page in the AWS Console.
- Under the "Permissions" tab, find the `AdministratorAccess` policy you just attached.
- Check the checkbox next to it and click the **"Remove"** (or "Detach") button.
- Confirm the removal.

If the pipeline works with `AdministratorAccess`, we'll know it's purely a permissions problem, and we can then work on a more secure, granular set of policies.
```

---

📝 Comprehensive Guide
For a detailed guide, please refer to the [Youtube video](https://youtu.be/dy1CkxQv0SM).
---
