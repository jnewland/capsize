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
  
  # TODO : TAKE THESE OUT OF HERE.  CONFIG SHOULD NOT BE EMBEDDED IN THE PLUGIN I THINK?
  # GENERAL CONFIG IS OK, BUT I THINK FALLING BACK TO SPECIFIC AMI's is prob not a good idea.
  # These defaults can also be added to the related methods as args = {:foo => "bar"} type defaults.  No?
  #set :aws_ami_id, "ami-f1b05598" # base centOS image
  #set :aws_security_group, "default"
  #set :aws_startup_delay, 60
  
  # Determine where we will deploy to.  if TARGET is not specified 
  # then setup for production by default
  set :deploy_env, ENV['TARGET'] ||= "production"
  
end