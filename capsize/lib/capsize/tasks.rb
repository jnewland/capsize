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
      
      desc ""
      desc <<-DESC
      Show instance console output.
      You can view the console of a specific instance by doing one of the following:
      - define an :instance_id in deploy.rb with "set :instance_id, 'i-123456'"
      - Overide this on the command line with "cap ec2:console:output INSTANCE_ID='i-123456'"
      - If neither of these are provided you will be prompted by Capistano for the instance ID you wish to terminate.
      DESC
      task :output do
        
        capsize.get_instance_id
        
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
      
      
      desc "Create and store a new keypair."
      task :create do
        begin
          capsize.create_keypair()
        rescue Exception => e
          puts "The attempt to create a keypair failed with the error : " + e
          raise e
        end
      end
      
      
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
      
      # TODO : GET THIS TASK WORKING WITH NEW AMAZON-EC2
      desc <<-DESC
      Runs an instance of aws_ami_id with aws_keypair_name.
      DESC
      task :run do
        instance_desc = capsize.run_instance({:ami_id => aws_ami_id, :keypair_name => aws_keypair_name})
        puts instance_desc.join("\t")
        set(:aws_instance_id, instance_desc[1])
        set(:aws_hostname, instance_desc[3])
        set(:target_role, aws_hostname)
        set_default_roles_to_target_role
      end
      
      desc "Terminate a specific instance."
      desc <<-DESC
      Terminates a specific instance.
      You can terminate a specific instance by doing one of the following:
      - define an :instance_id in deploy.rb with "set :instance_id, 'i-123456'"
      - Overide this on the command line with "cap ec2:terminate_instance INSTANCE_ID='i-123456'"
      - If neither of these are provided you will be prompted by Capistano for the instance ID you wish to terminate.
      DESC
      task :terminate do
        
        capsize.get_instance_id
        
        case instance_id
        when nil, ""
          puts "You don't seem to have set an instance ID..."
        else
          confirm = (Capistrano::CLI.ui.ask("REALLY terminate instance #{instance_id}? (y/N): ").downcase == 'y')
          if confirm
            begin
              response = capsize.terminate_instance({:instance_id => instance_id})
              puts "The request to terminate instance_id #{instance_id} has been accepted.  Monitor the status of the request with 'cap ec2:describe_instances'"
            rescue Exception => e
              puts "The attempt to terminate the instance failed with error : " + e
              raise e
            end
          else
            puts "Your terminate instance request has been cancelled."
          end
        end
      end
      
      
      desc "Info about your instances."
      task :describe do
        
        begin
          result = capsize.describe_instances()
        rescue Exception => e
          puts "The attempt to describe your instances failed with error : " + e
          raise e
        end
        
        unless result.reservationSet.nil?
          result.reservationSet.item.each do |reservation|
            puts "reservationSet:reservationId = " + reservation.reservationId
            puts "reservationSet:ownerId = " + reservation.ownerId
            
              unless reservation.groupSet.nil?
                reservation.groupSet.item.each do |group|
                  puts "  groupSet:groupId = " + group.groupId unless group.groupId.nil?
                end
              end
              
              unless reservation.instancesSet.nil?
                reservation.instancesSet.item.each do |instance|
                  puts "  instancesSet:instanceId = " + instance.instanceId unless instance.instanceId.nil?
                  puts "  instancesSet:imageId = " + instance.imageId unless instance.imageId.nil?
                  puts "  instancesSet:privateDnsName = " + instance.privateDnsName unless instance.privateDnsName.nil?
                  puts "  instancesSet:dnsName = " + instance.dnsName unless instance.dnsName.nil?
                  puts "  instancesSet:reason = " + instance.reason unless instance.reason.nil?
                  puts "  instancesSet:amiLaunchIndex = " + instance.amiLaunchIndex
                  
                  unless instance.instanceState.nil?
                    puts "  instanceState:code = " + instance.instanceState.code
                    puts "  instanceState:name = " + instance.instanceState.name
                  end
                  
                end
                
              end
              
            puts "" 
          end
        else
          puts "You don't own any running or pending instances"
        end
      end
      
    end
    
    
    # SECURITY GROUP TASKS
    #########################################
    
    namespace :security_groups do
      
      # TODO : GET THIS TASK WORKING WITH NEW AMAZON-EC2
      desc <<-DESC
      Opens tcp access on port 80 and 22 to the specified aws_security_group.
      DESC
      task :authorize_web_and_ssh_access do
        capsize.authorize_access({:group_name => aws_security_group, :from_port => "80"})
        capsize.authorize_access({:group_name => aws_security_group, :from_port => "22"})
      end
      
      # TODO : GET THIS TASK WORKING WITH NEW AMAZON-EC2
      desc <<-DESC
      Opens ip_protocol (tcp/udp) access on ports from_port-to_port to the specified aws_security_group.
      DESC
      task :authorize_port_range do
        capsize.authorize_access({:group_name => aws_security_group, :ip_protocol => ip_protocol, :from_port => from_port, :to_port => to_port})
      end
      
    end
    
    
    
    # IMAGE TASKS
    #########################################
    
    namespace :images do
      
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
    
    # BUG : I tried to put this task in a 'namespace :capsize do' block just like the others
    # this caused a nasty bug where I got the following error.  If I changed it to 'namespace :capsizer do' though it worked!!
    # WHY??? Report to Jamis?  Was a real PITA to track down...
    #
    # /usr/local/lib/ruby/gems/1.8/gems/capistrano-1.99.1/lib/capistrano/configuration/namespaces.rb:181:in `method_missing': undefined method `get_instance_id' for #<Capistrano::Configuration::Namespaces::Namespace:0x13cfce8> (NoMethodError)
    #       from /usr/local/lib/ruby/gems/1.8/gems/capsize-0.5.0/lib/capsize/tasks.rb:32
    #       from /usr/local/lib/ruby/gems/1.8/gems/capistrano-1.99.1/lib/capistrano/configuration/execution.rb:80:in `instance_eval'
    #       from /usr/local/lib/ruby/gems/1.8/gems/capistrano-1.99.1/lib/capistrano/configuration/execution.rb:80:in `execute_task_without_callbacks'
    #       from /usr/local/lib/ruby/gems/1.8/gems/capistrano-1.99.1/lib/capistrano/configuration/callbacks.rb:27:in `execute_task'
    #       from /usr/local/lib/ruby/gems/1.8/gems/capistrano-1.99.1/lib/capistrano/configuration/execution.rb:92:in `find_and_execute_task'
    #       from /usr/local/lib/ruby/gems/1.8/gems/capistrano-1.99.1/lib/capistrano/cli/execute.rb:43:in `execute_requested_actions_without_help'
    #       from /usr/local/lib/ruby/gems/1.8/gems/capistrano-1.99.1/lib/capistrano/cli/execute.rb:42:in `each'
    #       from /usr/local/lib/ruby/gems/1.8/gems/capistrano-1.99.1/lib/capistrano/cli/execute.rb:42:in `execute_requested_actions_without_help'
    #       from /usr/local/lib/ruby/gems/1.8/gems/capistrano-1.99.1/lib/capistrano/cli/help.rb:19:in `execute_requested_actions'
    #       from /usr/local/lib/ruby/gems/1.8/gems/capistrano-1.99.1/lib/capistrano/cli/execute.rb:31:in `execute!'
    #       from /usr/local/lib/ruby/gems/1.8/gems/capistrano-1.99.1/lib/capistrano/cli/execute.rb:14:in `execute'
    #       from /usr/local/lib/ruby/gems/1.8/gems/capistrano-1.99.1/bin/cap:4
    #       from /usr/local/bin/cap:16:in `load'
    #       from /usr/local/bin/cap:16
    
    
    # TODO : GET THIS TASK WORKING WITH NEW AMAZON-EC2
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
    
    # TODO : GET THIS TASK WORKING WITH NEW AMAZON-EC2
    # Sean : Can you describe what this is really doing?
    
    desc <<-DESC
    A hack that gets around the inability to set roles in a namespace.
    DESC
    task :set_default_roles_to_target_role do
      role :web, target_role
      role :app, target_role
      role :db, target_role, :primary => true
    end
  
  end
  
end