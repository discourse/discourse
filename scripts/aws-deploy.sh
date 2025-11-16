#!/bin/bash

# Discourse AWS Deployment Helper Script
# This script helps you deploy Discourse on AWS using Terraform

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
print_header() {
    echo -e "\n${GREEN}========================================${NC}"
    echo -e "${GREEN}$1${NC}"
    echo -e "${GREEN}========================================${NC}\n"
}

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"

    # Check for Terraform
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed"
        echo "Please install Terraform: https://www.terraform.io/downloads"
        exit 1
    fi
    print_info "Terraform found: $(terraform version | head -n1)"

    # Check for AWS CLI
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed"
        echo "Please install AWS CLI: https://aws.amazon.com/cli/"
        exit 1
    fi
    print_info "AWS CLI found: $(aws --version)"

    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured"
        echo "Please run: aws configure"
        exit 1
    fi
    print_info "AWS credentials configured"
    aws sts get-caller-identity
}

# Setup Terraform
setup_terraform() {
    print_header "Setting Up Terraform"

    cd terraform/aws

    if [ ! -f "terraform.tfvars" ]; then
        print_info "Creating terraform.tfvars from example..."
        cp terraform.tfvars.example terraform.tfvars
        print_warning "Please edit terraform.tfvars with your configuration"
        print_info "Opening terraform.tfvars in default editor..."
        ${EDITOR:-nano} terraform.tfvars
    else
        print_info "terraform.tfvars already exists"
    fi
}

# Initialize Terraform
init_terraform() {
    print_header "Initializing Terraform"

    cd terraform/aws
    terraform init
}

# Plan deployment
plan_deployment() {
    print_header "Planning Deployment"

    cd terraform/aws
    terraform plan -out=tfplan
}

# Apply deployment
apply_deployment() {
    print_header "Applying Deployment"

    cd terraform/aws

    print_warning "This will create AWS resources and incur costs!"
    read -p "Do you want to continue? (yes/no): " confirm

    if [ "$confirm" != "yes" ]; then
        print_info "Deployment cancelled"
        exit 0
    fi

    terraform apply tfplan

    print_header "Deployment Complete!"
    terraform output next_steps
}

# Destroy infrastructure
destroy_infrastructure() {
    print_header "Destroying Infrastructure"

    cd terraform/aws

    print_warning "This will DELETE all AWS resources!"
    read -p "Are you absolutely sure? Type 'yes' to confirm: " confirm

    if [ "$confirm" != "yes" ]; then
        print_info "Destruction cancelled"
        exit 0
    fi

    terraform destroy
}

# Show outputs
show_outputs() {
    print_header "Deployment Outputs"

    cd terraform/aws
    terraform output
}

# SSH into instance
ssh_instance() {
    print_header "Connecting to Instance"

    cd terraform/aws

    # Get instance IP
    INSTANCE_IP=$(terraform output -raw ec2_public_ip 2>/dev/null || echo "")

    if [ -z "$INSTANCE_IP" ] || [ "$INSTANCE_IP" == "N/A (using ALB)" ]; then
        print_error "Cannot connect: Simple mode not detected"
        print_info "Use AWS Systems Manager Session Manager for production deployments"
        exit 1
    fi

    # Get key name
    KEY_NAME=$(terraform output -json | jq -r '.ssh_command.value' | grep -oP '(?<=-i ~/.ssh/)[^ ]*' || echo "")

    if [ -z "$KEY_NAME" ]; then
        print_error "Cannot determine SSH key"
        read -p "Enter path to SSH key: " KEY_PATH
    else
        KEY_PATH="$HOME/.ssh/$KEY_NAME"
    fi

    print_info "Connecting to $INSTANCE_IP..."
    ssh -i "$KEY_PATH" ubuntu@$INSTANCE_IP
}

# Check Discourse status
check_status() {
    print_header "Checking Discourse Status"

    cd terraform/aws

    DOMAIN=$(terraform output -json | jq -r '.discourse_url.value' | sed 's|https://||')

    if [ -z "$DOMAIN" ]; then
        print_error "Cannot determine domain"
        exit 1
    fi

    print_info "Checking $DOMAIN..."

    if curl -sL -w "%{http_code}" "http://$DOMAIN" -o /dev/null | grep -q "200\|301\|302"; then
        print_info "Discourse is responding!"
    else
        print_warning "Discourse is not responding yet"
        print_info "It may still be bootstrapping (takes 10-15 minutes)"
    fi
}

# Main menu
show_menu() {
    echo ""
    echo "Discourse AWS Deployment Helper"
    echo "================================"
    echo "1. Check prerequisites"
    echo "2. Setup Terraform configuration"
    echo "3. Initialize Terraform"
    echo "4. Plan deployment"
    echo "5. Deploy infrastructure"
    echo "6. Show deployment outputs"
    echo "7. SSH into instance (simple mode)"
    echo "8. Check Discourse status"
    echo "9. Destroy infrastructure"
    echo "0. Exit"
    echo ""
}

# Main function
main() {
    if [ "$1" == "--auto" ]; then
        check_prerequisites
        setup_terraform
        init_terraform
        plan_deployment
        apply_deployment
        exit 0
    fi

    while true; do
        show_menu
        read -p "Select an option: " choice

        case $choice in
            1) check_prerequisites ;;
            2) setup_terraform ;;
            3) init_terraform ;;
            4) plan_deployment ;;
            5) apply_deployment ;;
            6) show_outputs ;;
            7) ssh_instance ;;
            8) check_status ;;
            9) destroy_infrastructure ;;
            0) exit 0 ;;
            *) print_error "Invalid option" ;;
        esac

        read -p "Press Enter to continue..."
    done
}

# Run main function
main "$@"
