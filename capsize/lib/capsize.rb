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

# Require all necessary libraries
%w[
  rubygems
  ostruct
  yaml
  fileutils
  builder
  capistrano
  EC2
  SQS
  capsize/version
  capsize/capsize.rb
  capsize/meta_tasks
  capsize/ec2
  capsize/ec2_plugin
  capsize/sqs
  capsize/sqs_plugin
  capsize/configuration
].each { |lib|
  begin
    require lib
  rescue Exception => e
    puts "The loading of '#{lib}' failed in capsize.rb with message : " + e
    exit
  end
}
