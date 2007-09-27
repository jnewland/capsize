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

# TODO : Add sqs and sqs_plugin when ready to include those.
# Require all necessary libraries
%w[
  rubygems
  capistrano
  EC2
  SQS
  ostruct
  yaml
  fileutils
  builder
  capsize/version
  capsize/configuration
  capsize/meta_tasks
  capsize/capsize.rb
  capsize/ec2
  capsize/ec2_plugin
].each { |lib|
  begin
    require lib
  rescue Exception => e
    puts "The loading of '#{lib}' failed in capsize.rb with message : " + e
    exit
  end
}
