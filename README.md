# AWS Infrastructure using the CLI

## Infrastructure Requirements:
- VPC:
    - Must support at least 50 Private IPs and 10 Public IPs.
    - Choose a suitable CIDR block and create subnets accordingly (public & private).

- EC2 Instances:
    - 1 Public Instance with internet access.
    - 1 Private Instance that must be able to get updates via NAT or a similar solution.
    - Both instances should allow SSH access for maintenance.
    - Install the latest system updates as part of the launch process.

