# CAPSIZE 'deploy.rb' SAMPLE
# Use this as a starting point for what you will need to add to your
# standard Capistrano deploy.rb file to make it function with Capsize.

# You will need to make sure that the Capsize 'cap' tasks are being included.
require 'capsize'

# Use this to overwrite the standard capsize config dir locations
#set :capsize_config_dir, 'config/capsize'
#set :capsize_secure_config_dir, 'config/capsize'

# Use these to overwrite the actual config file names stored in the config dirs.
#set :capsize_config_file_name, 'capsize.yml'
#set :capsize_secure_config_file_name, 'secure.yml'
