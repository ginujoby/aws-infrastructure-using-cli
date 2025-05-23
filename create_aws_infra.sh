#!/bin/bash

# Create VPC
vpc_id=$(aws ec2 create-vpc \
    --cidr-block 10.0.0.0/25 \
    --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=Script-VPC}]' \
    --query 'Vpc.VpcId' \
    --output text)

echo "VPC created: $vpc_id"

# Create Public Subnet
public_subnet_id=$(aws ec2 create-subnet \
    --vpc-id $vpc_id \
    --cidr-block 10.0.0.0/28 \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=Public Subnet}]' \
    --query 'Subnet.SubnetId' \
    --output text)

echo "Public Subnet created: $public_subnet_id"

# Create Private Subnet
private_subnet_id=$(aws ec2 create-subnet \
    --vpc-id $vpc_id \
    --cidr-block 10.0.0.64/26 \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=Private Subnet}]' \
    --query 'Subnet.SubnetId' \
    --output text)

echo "Private Subnet created: $private_subnet_id"


# Create Internet Gateway
igw_id=$(aws ec2 create-internet-gateway \
    --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=Script-IGW}]" \
    --query 'InternetGateway.InternetGatewayId' \
    --output text)

echo "Internet Gateway created: $igw_id"

# Attach Internet Gateway to the VPC
aws ec2 attach-internet-gateway \
    --internet-gateway-id $igw_id \
    --vpc-id $vpc_id

echo "Internet Gateway attached"

# Create Public Route Table
public_rtb_id=$(aws ec2 create-route-table \
    --vpc-id $vpc_id \
    --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=Public Route Table}]" \
    --query 'RouteTable.RouteTableId' \
    --output text)

# Create a Route. The route matches all IPv4 traffic and routes it to the Internet gateway
aws ec2 create-route \
    --route-table-id $public_rtb_id \
    --destination-cidr-block 0.0.0.0/0 \
    --gateway-id $igw_id

# Public Subnet Associations
aws ec2 associate-route-table \
    --subnet-id $public_subnet_id \
    --route-table-id $public_rtb_id

echo "Public Route Table created and associated."


# Allocate Elastic IP for NAT
elastic_ip_allocation_id=$(aws ec2 allocate-address \
    --domain vpc \
    --query 'AllocationId' \
    --output text)

# Create NAT Gateway
nat_gateway_id=$(aws ec2 create-nat-gateway \
    --subnet-id $public_subnet_id \
    --allocation-id $elastic_ip_allocation_id \
    --tag-specifications "ResourceType=natgateway,Tags=[{Key=Name,Value=Script-NAT-GW}]" \
    --query 'NatGateway.NatGatewayId' \
    --output text)

# Wait until NAT gateway is available
echo "Waiting for NAT Gateway to become available..."
aws ec2 wait nat-gateway-available \
    --nat-gateway-ids $nat_gateway_id

# Create Private Route Table
private_rtb_id=$(aws ec2 create-route-table \
    --vpc-id $vpc_id \
    --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=Private Route Table}]" \
    --query 'RouteTable.RouteTableId' \
    --output text)

# Create a Route
aws ec2 create-route \
    --route-table-id $private_rtb_id \
    --destination-cidr-block 0.0.0.0/0 \
    --nat-gateway-id $nat_gateway_id

# Private Subnet Associations
aws ec2 associate-route-table --subnet-id $private_subnet_id --route-table-id $private_rtb_id

echo "Private Route Table created and associated."


# Amazon Machine Image ID
ami_id=ami-0ec1ab28d37d960a9

# Find my IP
myIp=$(curl -s https://checkip.amazonaws.com)

# Create Security Group for Bastion Host
bastion_sg_id=$(aws ec2 create-security-group \
    --group-name "Bastion Security Group" \
    --description "Allow SSH" \
    --vpc-id $vpc_id \
    --query 'GroupId' \
    --output text)

echo "Bastion Security Group created: $bastion_sg_id"

# Adding Ingress Rule. Allow SSH only from my IP
aws ec2 authorize-security-group-ingress \
    --group-id $bastion_sg_id \
    --protocol tcp \
    --port 22 \
    --cidr $myIp/32

# Launch Bastion Host EC2
bastion_server_instance_id=$(aws ec2 run-instances \
    --image-id $ami_id \
    --instance-type t3.micro \
    --subnet-id $public_subnet_id \
    --key-name vockey \
    --associate-public-ip-address \
    --security-group-ids $bastion_sg_id \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value="Bastion Server"}]' \
    --query 'Instances[0].InstanceId' \
    --output text)

echo "Bastion Server created: $bastion_server_instance_id"


# Create Security Group for Private Instance
private_sg_id=$(aws ec2 create-security-group \
    --group-name "Private Security Group" \
    --description "Allow SSH only from Bastion" \
    --vpc-id $vpc_id \
    --query 'GroupId' \
    --output text)

echo "Private Security Group created: $private_sg_id"

# Adding Ingress Rule. Allow SSH only from Bastion/CIDR 
aws ec2 authorize-security-group-ingress \
    --group-id $private_sg_id \
    --protocol tcp \
    --port 22 \
    --cidr 10.0.0.0/28

# Launch Private Instance
private_server_instance_id=$(aws ec2 run-instances \
    --image-id $ami_id \
    --instance-type t3.micro \
    --subnet-id $private_subnet_id \
    --key-name vockey \
    --security-group-ids $private_sg_id \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value="Private Server"}]' \
    --query 'Instances[0].InstanceId' \
    --output text)

echo "Private Server created: $private_server_instance_id"
