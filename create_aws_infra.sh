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

echo "Internet Gateway attached: $igw_id"

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



