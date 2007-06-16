
# TODO : REDO THIS EXAMPLE!

require 'capsize'

set :user, "desired_user"
set :username, user

# Name of the keypair used to spawn and connect to the Amazon EC2 Instance
# Defaults to one created by the setup_keypair task 
set :aws_keypair_name, "#{application}-capsize"

# Path to the private key for the Amazon EC2 Instance mentioned above
# Detaults to one created by setup_keypair task
set :aws_private_key_path, "#{Dir.pwd}/#{aws_keypair_name}-key"

#defaults to an ubuntu image
#set :aws_ami_id, "ami-f1b05598" # base centOS image

#set :aws_security_group, "default"