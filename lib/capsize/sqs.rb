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

Capistrano::Configuration.instance.load do

  namespace :sqs do

    namespace :messages do

      task :receive do
        message = capsize_sqs.receive_message
        unless message.nil?
          puts message.body
        else
          puts "No Message"
        end
      end

      task :send_message do
        raise Exception, "message required" if capsize.get(:message).nil? || capsize.get(:message).empty?
        begin
          capsize_sqs.send_message(capsize.get(:message))
        rescue Exception => e
          raise e
        else
          puts "Message sent to #{capsize.get(:queue_name)} Queue"
        end
      end

    end

    namespace :queue do

      task :delete do
        begin
          raise Exception unless capsize_sqs.delete
        rescue Exception => e
          puts "Queue #{queue_name} not deleted"
          raise e
        else
          puts "Queue #{queue_name} deleted"
        end
      end

      task :delete! do
        begin
          raise Exception unless capsize_sqs.delete!
        rescue Exception => e
          puts "Queue #{queue_name} not deleted"
          raise e
        else
          puts "Queue #{queue_name} deleted"
        end
      end

    end

  end

end