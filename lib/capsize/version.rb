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

module Capsize #:nodoc:
  module VERSION #:nodoc:
    MAJOR = 0
    MINOR = 5
    TINY  = 0

    STRING = [MAJOR, MINOR, TINY].join('.')
  end
end
