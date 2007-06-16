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
%w[ rubygems capistrano EC2 ostruct yaml ].each { |f| require f }

Dir[File.join(File.dirname(__FILE__), 'capsize/**/*.rb')].sort.each { |lib| require lib }