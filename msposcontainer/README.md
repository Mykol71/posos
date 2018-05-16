# Teleflora Container Management Server
#
# Information line
# Status line
# Status line
# Status line
# - Main Menu
# 1. Container Management Installation
# 2. Images
# 3. Containers
# 4. VPN Connections
# 5. Status
# 6. Reporting
# 7. Exit
#
# Install prereqs
#
yum install -y epel-release
yum install -y python-pip git
pip install --upgrade pip
pip install awscli
echo "Run \$aws configure to setup AWS Account Access."
# 
# Container Image Build Process
#
# 1. Pull CentOS Docker base image
# 2. Start a CentOS base container
# 3. Gather customer information
# 4. Configure Amazon VPC VPN Connection
# 5. Validate
# 6. Staging process for POS Application
# 7. Configure mounted customer cloud POS filesystem
# 8. Create image with Customer specific configuration
# 9. ...
#
# Container deployment process
# 1. Deloyment commands
# 2. ...
# 3. ...
#
# Container Management
# 1. Running Containers
# 2. Stop/Start/Attach to running containers
# 3. Tracking running time for billing purposes
# 4. ...
#
# Reporting
# 1. Statistics of solution in CVS file(s) for Kaseya reporting mechanism
# 2. Scheduling maintenance of reporting data
# 3. 
