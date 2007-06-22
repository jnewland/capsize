#--
# Capistrano Plugin which provides access to the amazon-ec2 gem's methods
#
# Ruby Gem Name::  capsize
# Author::    Glenn Rempe  (mailto:glenn@elasticworkbench.com)
# Author::    Jesse Newland  (mailto:jnewland@gmail.com)
# Copyright:: Copyright (c) 2007 Glenn Rempe, Jesse Newland
# License::   Distributes under the same terms as Ruby
# Home::      http://capsize.rubyforge.org
#++

Capistrano::Configuration.instance.load do
  
  namespace :ec2 do
    
    desc <<-DESC
    Initialize the Capsize configuration for a rails app. Do:
    - Copy capsize.yml.template to config/ dir
    - Copy secure.yml.template to config/ dir
    - Instruct user to add AWS keys to secure.yml or capsize.yml
    - Instruct user to test configuration with "cap ec2:images:describe"
    - Prompt user to ask if they want to run "cap ec2:keypairs:create"
    DESC
    task :setup_config_files do
      capsize.copy_file
    end
    
  end
  
  # TODO : GET THIS TASK WORKING WITH NEW AMAZON-EC2
  # TODO : GET THIS TASK WORKING WITH NEW TASKS HERE, AND MAKE SURE WE ARE DOING THE RIGHT STEPS?
  # TODO : ADD FULL CAP -E DOCS HERE
  #desc <<-DESC
  #A task that does everything the other tasks do, all at once, and prompts for required variables if they don't exist.
  #DESC
  #task :setup do
  #  set(:capsize_interactive_setup, true)
  #  set :access_key_id, fetch(:access_key_id) {Capistrano::CLI.password_prompt("Amazon EC2 Access Key ID: ")}
  #  set :secret_access_key, fetch(:secret_access_key) {Capistrano::CLI.password_prompt("Amazon EC2 Secret Access Key: ")}
  #  set :key_name, fetch(:key_name, "#{application}-capsize")
  #  set :key_dir, fetch(:key_dir, "#{Dir.pwd}/#{key_name}-key")
  #  ec2.create_keypair
  #  ec2.run_instance
  #  ec2.authorize_web_and_ssh_access
  #  ec2.setup_user
  #end
  
  
  # TODO : GET THIS TASK WORKING WITH NEW AMAZON-EC2
  # TODO : Do we really still need this?  Perhaps instead of kicking out
  # text to add to deploy.rb, we should copy over the template config files (secure.yml and capsize.yml)
  # to the rails config dir.  No?
  # TODO : ADD FULL CAP -E DOCS HERE
  desc <<-DESC
  Writes out the config keys pertaining to capsize.
  DESC
  task :generate_config do
    puts "Please add this to your config/deploy.rb"
    puts "----------------------------------------"
    
    puts "\n#capsize Config"
    puts "require 'capsize'"
    
    puts "\n#AWS config"
    aws_variables =  variables.select { |key, value| key.to_s =~ /aws_/ }
    unless aws_variables.empty?
      aws_variables.each do |key_value_array|
        puts "set(:#{key_value_array.first}, '#{variables[key_value_array.first]}')" if variables[key_value_array.first].class == String
      end
    end
    puts "\n"
    puts "role :web, aws_hostname"
    puts "role :app, aws_hostname"
    puts "role :db, aws_hostname, :primary => true"
    puts "\n" 
  end
  
  
  # TODO : Should these be defined here? Doesn't that mean that every
  # time a deploy:setup is run these tasks are run also?  Can they
  # really be run in all circumstances without harm if repeated?
  # Lets discuss...
  
  #callbacks to make this stuff happen
  #before "deploy:setup", "ec2:setup"
  #after "deploy:setup", "ec2:generate_config"
  
  
end