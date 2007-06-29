#--
# Capsize : A Capistrano Plugin which provides access to the amazon-ec2 gem's methods
#
# Ruby Gem Name::  capsize
# Author::    Glenn Rempe  (mailto:grempe@rubyforge.org)
# Author::    Jesse Newland  (mailto:jnewland@gmail.com)
# Copyright:: Copyright (c) 2007 Glenn Rempe, Jesse Newland
# License::   Distributes under the same terms as Ruby
# Home::      http://amazon-ec2-cap.rubyforge.org
#++

Capistrano::Configuration.instance.load do
  
  # Set reasonable defaults for all needed values so in theory this Cap plugin
  # will work out-of-the-box with no external config required.  Users
  # can also opt to set any of these in their deploy.rb file to override them.
  
  # capsize_config_dir is relative to the location they are running cap from (e.g. RAILS_ROOT)
  # TODO: Glenn - this directory either needs to exist or be created by capsize somehow. This is why I had defaulted to config before.      
  # Jesse : RESPONSE : Its created by the setup :default task (in meta-tasks) if it doesn't exist.  
  # Running setup your first time using Capsize is required.  You can of course override 
  # this dir in your config to make it any arbitrary location. Please erase this comment and the todo if this
  # answers your question satisfactorily.  :-)
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
  set :deploy_env, ENV['TARGET'] ||= "production"
  
  # defaults for new security groups
  set :group_name, nil
  set :group_description, "Default security group for the \"#{application}\" application."
  
  set :ip_protocol, 'tcp'
  set :from_port, nil
  set :to_port, nil
  set :cidr_ip, '0.0.0.0/0'
  set :source_security_group_name, nil
  set :source_security_group_owner_id, nil
  
  set :image_id, nil
  set :min_count, 1
  set :max_count, 1
  set :key_name, "#{application}"
  set :queue_name, "#{application}"
  set :user_data, nil
  set :addressing_type, 'public'
  
end