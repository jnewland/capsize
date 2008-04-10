# CAPSIZE 'deploy.rb' SAMPLE
# Use this as a starting point for what you will need to add to your
# standard Capistrano deploy.rb file to make it function with Capsize.

# #################################################################
# CAPSIZE CONFIG SETTINGS
# #################################################################

# Include the Capsize EC2 'cap' tasks
# WARNING : This must be placed in your deploy.rb file anywhere 
# AFTER the line where you set your application name!  Looks like:
#   set :application, "foobar".
# The application name is used by Capsize and the order matters!
require 'capsize'

# Uncomment to override the standard capsize config dir
# used for standard config info.
#set :capsize_config_dir, 'config/capsize'

# Uncomment to override location used to store a 
# secure config file with your AWS credentials,
# and EC2 private keypair information.
#set :capsize_secure_config_dir, 'config/capsize'

# Uncomment to override the actual config file names 
# that are stored in the config dirs noted above.
#set :capsize_config_file_name, 'capsize.yml'
#set :capsize_secure_config_file_name, 'secure.yml'

