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
  
  namespace :ec2 do
    
    
    # CONSOLE TASKS
    #########################################
    
    namespace :console do
      
      desc <<-DESC
      Show instance console output.
      You can view the console of a specific instance by doing one of the following:
      - define an :instance_id in deploy.rb with "set :instance_id, 'i-123456'"
      - Overide this on the command line with "cap ec2:console:output INSTANCE_ID='i-123456'"
      - If neither of these are provided you will be prompted by Capistano for the instance ID you wish to terminate.
      DESC
      task :output do
        
        capsize.get(:instance_id)
        
        case instance_id
        when nil, ""
          puts "You don't seem to have set an instance ID..."
        else
          begin
            capsize.get_console_output(:instance_id => instance_id).each_pair do |key, value|
              puts "#{key} = #{value}" unless key == "xmlns"
            end
          rescue Exception => e
            puts "The attempt to get the console output failed with error : " + e
            raise e
          end
        end
        
      end
      
    end
    
    
    # KEYPAIR TASKS
    #########################################
    
    namespace :keypairs do
      
      # TODO : ADD FULL CAP -E DOCS HERE
      desc "Describes your keypairs."
      task :describe do
        begin
            capsize.describe_keypairs().keySet.item.each do |item|
            puts "keyName = " + item.keyName
            puts "keyFingerprint = " + item.keyFingerprint
            puts "" 
          end
        rescue Exception => e
          puts "The attempt to describe your keypairs failed with error : " + e
          raise e
        end
      end
      
      
      # TODO : ADD FULL CAP -E DOCS HERE
      desc "Create and store a new keypair."
      task :create do
        begin
          capsize.create_keypair()
        rescue Exception => e
          puts "The attempt to create a keypair failed with the error : " + e
          raise e
        end
      end
      
      
      # TODO : ADD FULL CAP -E DOCS HERE
      desc "Delete a keypair from EC2 and local files."
      task :delete do
        
        confirm = (Capistrano::CLI.ui.ask("REALLY delete keypair for this application?  You will no longer be able to access any running instances!? (y/N): ").downcase == 'y')
        if confirm
          begin
            capsize.delete_keypair()
          rescue Exception => e
            puts "The attempt to delete the keypair failed with the error : " + e
            raise e
          end
        end
      end
      
    end
    
    
    # INSTANCES TASKS
    #########################################
    
    namespace :instances do
      
      # TODO : keypairs:create automatically saves the key pair with the name of the application in the config dir.  We
      # should make it so that it uses that if it exists, and only get() it from the config if that is not found?
      # TODO : ADD FULL CAP -E DOCS HERE
      desc <<-DESC
      Runs an instance of aws_ami_id with aws_keypair_name.
      DESC
      task :run do
        response = capsize.run_instance({:image_id => capsize.get(:aws_ami_id), :keypair_name => capsize.get(:aws_keypair_name)})
        capsize.print_instance_description(response)
        set(:aws_instance_id, response.reservationSet.item[0].instancesSet.item[0].instanceId)
        set(:aws_hostname, response.reservationSet.item[0].instancesSet.item[0].dnsName)
        set(:target_role, aws_hostname)
        set_default_roles_to_target_role
      end
      
      desc <<-DESC
      Terminate an EC2 instance.
      You can terminate a specific instance by doing one of the following:
      - define an :instance_id in deploy.rb with "set :instance_id, 'i-123456'"
      - Overide this on the command line with "cap ec2:instances:terminate INSTANCE_ID='i-123456'"
      - If neither of these are provided you will be prompted by Capistano for the instance ID you wish to terminate.
      DESC
      task :terminate do
        
        capsize.get(:instance_id)
        
        case instance_id
        when nil, ""
          puts "You don't seem to have set an instance ID..."
        else
          confirm = (Capistrano::CLI.ui.ask("REALLY terminate instance #{instance_id}? (y/N): ").downcase == 'y')
          if confirm
            begin
              response = capsize.terminate_instance({:instance_id => instance_id})
              puts "The request to terminate instance_id #{instance_id} has been accepted.  Monitor the status of the request with 'cap ec2:instances:describe'"
            rescue Exception => e
              puts "The attempt to terminate the instance failed with error : " + e
              raise e
            end
          else
            puts "Your terminate instance request has been cancelled."
          end
        end
      end
      
      
      desc <<-DESC
      Reboot an EC2 instance.
      You can reboot a specific instance by doing one of the following:
      - define an :instance_id in deploy.rb with "set :instance_id, 'i-123456'"
      - Overide this on the command line with "cap ec2:instances:reboot INSTANCE_ID='i-123456'"
      - If neither of these are provided you will be prompted by Capistano for the instance ID you wish to reboot.
      DESC
      task :reboot do
        
        capsize.get(:instance_id)
        
        case instance_id
        when nil, ""
          puts "You don't seem to have set an instance ID..."
        else
          confirm = (Capistrano::CLI.ui.ask("REALLY reboot instance #{instance_id}? (y/N): ").downcase == 'y')
          if confirm
            begin
              response = capsize.reboot_instance({:instance_id => instance_id})
              puts "The request to reboot instance_id #{instance_id} has been accepted.  Monitor the status of the request with 'cap ec2:instances:describe'"
            rescue Exception => e
              puts "The attempt to reboot the instance failed with error : " + e
              raise e
            end
          else
            puts "Your reboot instance request has been cancelled."
          end
        end
      end
      
      
      # TODO : ADD FULL CAP -E DOCS HERE
      desc "Info about your instances."
      task :describe do
        
        begin
          result = capsize.describe_instances()
        rescue Exception => e
          puts "The attempt to describe your instances failed with error : " + e
          raise e
        end
        
        capsize.print_instance_description(result)
      end
      
    end
    
    
    # SECURITY GROUP TASKS
    #########################################
    
    
    namespace :security_groups do
      
      desc <<-DESC
      Authorize firewall ingress for the specified GROUP_NAME and FROM_PORT.
      This calls authorize_ingress for the group defined in the :group_name variable
      and the port specified in :from_port and :to_port. Any instances that were started and set to
      use the security group :group_name will be affected as soon as possible. You can 
      specify a port range, instead of a single port if both FROM_PORT and TO_PORT are passed in.
      DESC
      task :authorize_ingress do
        
        begin
          capsize.authorize_ingress({:group_name => capsize.get(:group_name), :from_port => capsize.get(:from_port), :to_port => capsize.get(:to_port)})
          puts "Firewall ingress granted for :group_name => #{capsize.get(:group_name)} on ports #{capsize.get(:from_port)} to #{capsize.get(:to_port)}"
        rescue EC2::InvalidPermissionDuplicate => e
          puts "The firewall ingress rule you specified for group name \"#{capsize.get(:group_name)}\" on ports #{capsize.get(:from_port)} to #{capsize.get(:to_port)} was already set (EC2::InvalidPermissionDuplicate)."
          # Don't re-raise this exception
        rescue Exception => e
          puts "The attempt to allow firewall ingress on port #{capsize.get(:from_port)} to #{capsize.get(:to_port)} for security group \"#{capsize.get(:group_name)}\" failed with the error : " + e
          raise e
        end
        
      end
      
      
      desc <<-DESC
      Revoke firewall ingress for the specified GROUP_NAME and FROM_PORT.
      This calls revoke_ingress for the group defined in the :group_name variable
      and the port specified in :from_port and :to_port. Any instances that were started and set to
      use the security group :group_name will be affected as soon as possible. You can 
      specify a port range, instead of a single port if both FROM_PORT and TO_PORT are passed in.
      DESC
      task :revoke_ingress do
        
        begin
          capsize.revoke_ingress({:group_name => capsize.get(:group_name), :from_port => capsize.get(:from_port), :to_port => capsize.get(:to_port)})
          puts "Firewall ingress revoked for :group_name => #{capsize.get(:group_name)} on ports #{capsize.get(:from_port)} to #{capsize.get(:to_port)}"
        rescue Exception => e
          puts "The attempt to revoke firewall ingress permissions on port #{capsize.get(:from_port)} to #{capsize.get(:to_port)} for security group \"#{capsize.get(:group_name)}\" failed with the error : " + e
          raise e
        end
        
      end
      
    end
    
    
    # IMAGE TASKS
    #########################################
    
    # TODO : separate public/private image list methods?, No, prob better to be able to pass in a param to say:
    # OWNER_ID = "self", or "amazon", or the other options allowed...
    
    namespace :images do
      
      # TODO : ADD FULL CAP -E DOCS HERE
      desc "Describe machine images you can execute."
      task :describe do
        begin
          capsize.describe_images().imagesSet.item.each do |item|
            puts "imageId = " + item.imageId unless item.imageId.nil?
            puts "imageLocation = " + item.imageLocation unless item.imageLocation.nil?
            puts "imageOwnerId = " + item.imageOwnerId unless item.imageOwnerId.nil?
            puts "imageState = " + item.imageState unless item.imageState.nil?
            puts "isPublic = " + item.isPublic unless item.isPublic.nil?
            puts "" 
          end
        rescue Exception => e
          puts "The attempt to describe images failed with error : " + e
          raise e
        end
      end
      
    end
    
    
    # CAPSIZE TASKS
    #########################################
    
    
    # TODO : GET THIS TASK WORKING WITH NEW AMAZON-EC2
    # TODO : ADD FULL CAP -E DOCS HERE
    desc <<-DESC
    Creates a secure root password, adds a user, and gives that user sudo privileges on aws_hostname.
    This doesn't use Net::SSH, but rather shells out to SSH to access the host w/ private key auth.
    DESC
    task :setup_user do
      if capsize_interactive_setup
        puts "Waiting #{aws_startup_delay} for #{aws_hostname} to boot..."
        sleep aws_startup_delay.to_i
      end
      set :user, fetch(:user) {`whoami`.chomp}
      puts "\nConnecting to #{aws_hostname}..."
      puts "\nPlease create a secure root password"
      system "ssh -o StrictHostKeyChecking=no -i #{aws_private_key_path} root@#{aws_hostname} passwd"
      puts "\nCreating #{user} user"
      system "ssh -o StrictHostKeyChecking=no -i #{aws_private_key_path} root@#{aws_hostname} 'useradd -m -G wheel -s /bin/bash #{user} && passwd #{user}'"
      puts "Adding wheel group to sudoers"
      system "ssh -o StrictHostKeyChecking=no -i #{aws_private_key_path} root@#{aws_hostname} 'chmod 640 /etc/sudoers; echo -e \"#{user}\tALL=(ALL)\tALL\" >> /etc/sudoers;chmod 440 /etc/sudoers'"
      puts "Ensuring #{user} has permissions on #{deploy_to}"
      system "ssh -o StrictHostKeyChecking=no -i #{aws_private_key_path} root@#{aws_hostname} 'umask 02 && mkdir -p #{deploy_to} && chown #{user}:wheel #{deploy_to}'"
    end
      
    
    # CAPISTRANO TASKS
    #########################################
    
    # This helper method is called in instances:run to set the default roles to the newly spawned EC2 instance
    # no desc "" so this method does not show up in 'cap -T' listing as it should not be called directly.
    task :set_default_roles_to_target_role do
      role :web, target_role
      role :app, target_role
      role :db, target_role, :primary => true
    end
  
  end
  
end