Capistrano::Configuration.instance.load do

  # Set reasonable defaults for all needed values so in theory this Cap plugin
  # will work out-of-the-box with no external config required.  Users
  # can also opt to set any of these in their deploy.rb file to override them.

  set :capsize_config_dir, 'config/capsize'
  set :capsize_secure_config_dir, 'config/capsize'

  set :capsize_config_file_name, 'capsize.yml'
  set :capsize_secure_config_file_name, 'secure.yml'

  # Where are the various extra capsize files stored?  Make them easy to get() or override
  set :capsize_examples_dir, "#{File.join(File.dirname(__FILE__), '/../../examples')}"
  set :capsize_bin_dir, "#{File.join(File.dirname(__FILE__), '/../../bin')}"

  # Determine where we will deploy to.  if TARGET is not specified
  # then setup for 'production' environment by default.
  # TODO : CHANGE THIS TO TARGET_ENV IN HERE AND AMAZON-EC2, and in my app
  # TODO : Make this work with capistrano-ext
  set :deploy_env, ENV['TARGET'] ||= "production"

  # defaults for new security groups
  set :group_name, nil
  set :group_description, nil

  set :ip_protocol, 'tcp'
  set :from_port, nil
  set :to_port, nil
  set :cidr_ip, '0.0.0.0/0'
  set :source_security_group_name, nil
  set :source_security_group_owner_id, nil

  set :image_id, nil
  set :min_count, 1
  set :max_count, 1
  set :instance_type, 'm1.small'
# FIXME : Breaks loading of this file and tests
#  set :key_name, "#{application}"
#  set :queue_name, "#{application}"
  set :user_data, nil
  set :addressing_type, 'public'
  set :availability_zone, nil

end