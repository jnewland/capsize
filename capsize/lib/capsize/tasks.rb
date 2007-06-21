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
    
    
    # SSH TASKS
    #########################################
    
    # TODO : Add a task that will let you SSH to a specific instance ID using public key auth.
    # example connect :  ssh -i config/elasticworkbench.key root@ec2-72-44-51-229.z-1.compute-1.amazonaws.com
    
    # CONSOLE TASKS
    #########################################
    
    namespace :console do
      
      desc <<-DESC
      Show instance console output.
      You can view the console of a specific instance by doing one of the following:
      - define an :instance_id in any Capsize config file with "set :instance_id, 'i-123456'"
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
      
      desc <<-DESC
      Describes your keypairs.
      This will return a text description of all of your personal keypairs created on EC2.
      Remember that these keypairs are only usable if you have the private key material stored locally
      and you specify this keypair as part of the run instances command.  Only then will you be able to
      take advantage of logging into remote servers using public key authentication.  This command 
      will also display whether you have a locally installed private key that matches the key_name of
      the public key being described.
      DESC
      task :describe do
        begin
          capsize.describe_keypairs().keySet.item.each do |item|
            puts "[#{item.keyName}] : keyName = " + item.keyName
            puts "[#{item.keyName}] : keyFingerprint = " + item.keyFingerprint
            
            # tell them if they have the matching private key stored locally and available
            key_name = item.keyName
            key_dir = capsize.get(:key_dir) unless capsize.get(:key_dir).nil? || capsize.get(:key_dir).empty?
            key_file = [key_dir, key_name].join('/') + '.key'
            
            puts "[#{item.keyName}] : OK : matching local private key found @ #{key_file}" if File.exists?(key_file)
            puts "[#{item.keyName}] : WARNING : matching local private key NOT found @ #{key_file}" unless File.exists?(key_file)
            puts "" 
          end
        rescue Exception => e
          puts "The attempt to describe your keypairs failed with error : " + e
          raise e
        end
      end
      
      
      desc <<-DESC
      Create and store a new keypair.
      This command will generate a new keypair for you on EC2 and will also
      save a local copy of your private key in the filepath specified by
      KEY_DIR and KEY_NAME.  By default the keypair will be named the
      same as your Capistrano application name, and the private key will
      be stored at 'config/<appname>.key'.  If a keypair already exists
      on the EC2 servers or locally with the same name it will not be
      overwritten.
      
      WARNING : Keypair private keys should be protected the same as passwords.
      If you have specified a key_name to use when running instances anyone who 
      has access to your keypair private key file contents and who knows the 
      public DNS name of your servers may be able to login to those servers 
      without providing a password.  Use caution when storing the private key file
      in source code control systems, and keep a backup of your private key file.
      DESC
      task :create do
        begin
          capsize.create_keypair()
        rescue Exception => e
          puts "The attempt to create a keypair failed with the error : " + e
          raise e
        end
      end
      
      
      # TODO : this should be able to delete any keypair, not just the default one!
      desc <<-DESC
      Delete a keypair.
      This command will delete a keypair from EC2 and will also
      delete the local copy of your private key in the filepath specified by
      KEY_DIR and KEY_NAME.  By default the keypair deleted will be named the
      same as your Capistrano application name, and the private key will
      be deleted from 'config/<appname>.key'.  You will be prompted to confirm
      deletion of your keypair before the action will proceed.
      
      WARNING : Don't delete keypairs which may be associated with
      running instances on EC2.  If you do so you may lose the ability
      to access these servers via SSH and Capistrano!  Your last resort in 
      this case may be to terminate those running servers.
      DESC
      task :delete do
        
        unless capsize.get(:key_name).nil? || capsize.get(:key_name).empty?
          key_name = capsize.get(:key_name)
        else
          key_name = "#{application}"
        end
        
        confirm = (Capistrano::CLI.ui.ask("WARNING! Are you sure you want to delete the local and remote parts of the keypair with the name \"#{key_name}\"?\nYou will no longer be able to access any running instances that depend on this keypair!? (y/N): ").downcase == 'y')
        
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
      Runs an instance of :image_id with the keypair :key_name.
      DESC
      task :run do
        begin
          
          response = capsize.run_instance
          
          puts "An instance has been started with the following metadata:"
          capsize.print_instance_description(response)
          
          # TODO : FIX this SSH string so it matches their key info and the host that was started
          #puts "You should be able to connect via SSH without specifying a password with a command like:"
          #puts "  ssh -i config/elasticworkbench.key root@ec2-72-44-51-229.z-1.compute-1.amazonaws.com"
          
          # TODO : Tell the user exactly what they need to put in their deploy.rb
          # to make the control of their server instances persistent!
          #capsize.print_config_instructions(:response => response)
          
          # TODO : I think this (set_default_roles_to_target_role) is only good if we are only 
          # dealing with one server.  But the values are temporary.  How should we handle multiple 
          # instances starting that need to be controlled?  How should we handle storing this important data
          # more persistently??
          #
          # override the roles set in deploy.rb with the server instance started here.
          # This is temporary and only remains defined for the length of this 
          # capistrano run!
          set(:dns_name, response.reservationSet.item[0].instancesSet.item[0].dnsName)
          set_default_roles_to_target_role
          
        rescue Exception => e
          puts "The attempt to run an instance failed with the error : " + e
        end
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
          confirm = (Capistrano::CLI.ui.ask("WARNING! Really terminate instance \"#{instance_id}\"? (y/N): ").downcase == 'y')
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
          confirm = (Capistrano::CLI.ui.ask("WARNING! Really reboot instance \"#{instance_id}\"? (y/N): ").downcase == 'y')
          if confirm
            begin
              response = capsize.reboot_instance({:instance_id => instance_id})
              puts "The request to reboot instance_id \"#{instance_id}\" has been accepted.  Monitor the status of the request with 'cap ec2:instances:describe'"
            rescue Exception => e
              puts "The attempt to reboot the instance_id \"#{instance_id}\" failed with error : " + e
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
    
    
    # TODO : ADD DESCRIBE SECURITY GROUPS TASK AND PLUGIN METHOD!
    
    
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
      
  end # end namespace :ec2
  
  # This helper method is called in instances:run to set the default roles to 
  # the newly spawned EC2 instance.
  #
  # no desc "" is provided to ensure this method does not show up in 'cap -T' 
  # listing as it generally would not be called directly.
  # Hack? : This method must be defined outside of a namespace or it will raise an exception!
  #
  task :set_default_roles_to_target_role do
    role :web, dns_name
    role :app, dns_name
    role :db, dns_name, :primary => true
  end
  
end # end Capistrano::Configuration.instance.load