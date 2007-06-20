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
  # will work out-of-the-box with no external config required.
  
  #set :aws_startup_delay, 60
  
  # Determine where we will deploy to.  if TARGET is not specified 
  # then setup for production by default
  # TODO : CHANGE THIS TO TARGET_ENV IN HERE AND AMAZON-EC2
  set :deploy_env, ENV['TARGET'] ||= "production"
  
  # Set the security group name default to the 'default' group.
  set :group_name, 'default'
  
end