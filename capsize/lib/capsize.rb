#--
# Capsize : A Capistrano Plugin which provides access to the amazon-ec2 gem's methods
#
# Ruby Gem Name::  capsize
# Author::    Glenn Rempe  (mailto:grempe@rubyforge.org)
# Author::    Jesse Newland  (mailto:jnewland@gmail.com)
# Copyright:: Copyright (c) 2007 Glenn Rempe, Jesse Newland
# License::   Distributes under the same terms as Ruby
# Home::      http://capsize.rubyforge.org
#++

# require necessary libraries


require 'capsize/version'
require 'capsize/configuration'
require 'capsize/capsize'
require 'capsize/capsize_plugin'
require 'capsize/ec2'
require 'capsize/meta_tasks'
require 'capsize/sqs_plugin'
require 'capsize/sqs'

%w[ rubygems capistrano EC2 ostruct yaml fileutils SQS builder ].each { |f| require f }
