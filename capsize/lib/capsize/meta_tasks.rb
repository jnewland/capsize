#--
# Capistrano Plugin which provides access to the amazon-ec2 gem's methods
#
# Ruby Gem Name::  capsize
# Author::    Glenn Rempe  (mailto:grempe@rubyforge.org)
# Author::    Jesse Newland  (mailto:jnewland@gmail.com)
# Copyright:: Copyright (c) 2007 Glenn Rempe, Jesse Newland
# License::   Distributes under the same terms as Ruby
# Home::      http://capsize.rubyforge.org
#++

@config = Capistrano::Configuration.new

@config.load do

  namespace :ec2 do
    
    namespace :setup do
      
      desc <<-DESC
      Initialize Capsize config.
      You can run this command as often as you like.
      It will not overwrite config files on multiple runs.
      - Create :capsize_config_dir
      - Create :capsize_secure_config_dir
      - Copy capsize.yml.template to :capsize_config_dir/capsize.yml unless it already exists
      - Copy secure.yml.template to :capsize_secure_config_dir/secure.yml unless it already exists
      - Instruct user to add AWS keys to secure.yml or capsize.yml
      - Instruct user to test configuration with "cap ec2:images:describe"
      - Instruct user how to create a new keypair
      - Instruct user how to setup a new security group.
      DESC
      task :default do
        
        # Make the standard config dir if it doesn't exist already
        unless File.exists?(fetch(:capsize_config_dir))
          FileUtils.mkdir fetch(:capsize_config_dir)
        end
        
        # Make the secure config dir if it doesn't exist already
        unless File.exists?(fetch(:capsize_secure_config_dir))
          FileUtils.mkdir fetch(:capsize_secure_config_dir)
        end
        
        # copy the standard config file template, unless the dest file alread exists
        unless File.exists?("#{fetch(:capsize_config_dir)}/#{fetch(:capsize_config_file_name)}")
          FileUtils.cp("#{fetch(:capsize_examples_dir)}/capsize.yml.template", "#{fetch(:capsize_config_dir)}/#{fetch(:capsize_config_file_name)}", :verbose => true)
        else
          puts "Warning : The following file was not copied over since it already exists: " + "#{fetch(:capsize_config_dir)}/#{fetch(:capsize_config_file_name)}"
        end
        
        # copy the secure config file template, unless the dest file alread exists
        unless File.exists?("#{fetch(:capsize_secure_config_dir)}/#{fetch(:capsize_secure_config_file_name)}")
          FileUtils.cp("#{fetch(:capsize_examples_dir)}/secure.yml.template", "#{fetch(:capsize_secure_config_dir)}/#{fetch(:capsize_secure_config_file_name)}", :verbose => true)
        else
          puts "Warning : The following file was not copied over since it already exists: " + "#{fetch(:capsize_secure_config_dir)}/#{fetch(:capsize_secure_config_file_name)}"
        end
        
        message = <<-MESSAGE
        
        Capsize Config Setup Instructions:
        
        Step 1:
        
          Your Capsize config files have been created.  You should now add your
          Amazon Web Services 'Access Key ID' and 'Secret Access Key' to the secure.yml
          file we created for you in your config dir.
          
          Once you have done this you should be able to test out your ability to use 
          Capsize by running the following command:
          
            RUN:
            
            cap ec2:setup:check
          
          If you receive a congratulatory response then you are ready to continue using Capsize.
          If you receive an Exception message please use that to help you troubleshoot further.
          
          Once you have succesfully tested your connection to EC2, please continue with the next
          steps...
        
        Step 2 : Create a new key pair (highly recommended but optional):
        
          Once you have completed the first step successfully, the next recommended step 
          is to create a an Amazon EC2 keypair that is specifically tailored for use 
          with your application.  This keypair will be used to allow you to create new 
          EC2 instances that can accept public key authentication for passwordless login.
          By default the keypair created will be named the same as the :application setting
          in your deploy.rb file (run 'cap -e ec2:keypairs:create' for more info.).
          
          Setting up a new keypair in this fashion does not preclude you from using a 
          different keypair of your choice in the future.
          
          Run the following command to create a new keypair for your application:
            
            RUN:
            
            cap ec2:keypairs:create
          
          WARNING:
          Once you successfully create your keypair, guard your new private key carefully
          as it allows the holder of that key to access EC2 instances started using that key.
          
        Step 3 : Create a new security group + open ports (highly recommended but optional):
        
          Security groups contain a set of firewall rules that apply to any 
          EC2 instance started that is configured to use that specific security 
          group.  Running the command below will create a new security group
          that is named after your :application setting in deploy.rb which you can 
          use instead of the 'default' security group that EC2 creates for you.
          
          This command will also open firewall ports for your new group that match the standard
          web ports most applications need (22-SSH, 80-HTTP, 443-HTTPS).  If this is
          not suitable for you then please read the docs for 'ec2:security_groups:create'
          and 'ec2:security_groups:authorize_ingress'
            
            RUN:
            
            cap ec2:security_groups:create_with_standard_ports
          
          -------------------------------------------------------------------------------
          At this point your configuration is complete and we can get down to running and
          using Amazon EC2 instances.  In most cases, you should not have to repeat any 
          of the previous commands again.
          -------------------------------------------------------------------------------
          
        Step 4 : Pick an Amazon Machine Image and Run it!
          
          Now you need to select an Amazon EC2 image ID that you want to start as a new
          instance.  The easiest way to do that is to get a list of available images from EC2.
            
            RUN (pick one):
            
            # Show ALL registered images
            cap ec2:images:describe
            
            # Show MY registered images
            cap ec2:images:describe OWNER_ID='self'
            
            # Show the AMAZON registered images
            cap ec2:images:describe OWNER_ID='amazon'
          
          Select an 'imageId' from the results, it will look like:  'ami-2bb65342'
          
          Now lets start it:
          
            RUN :
            
            cap ec2:instances:run IMAGE_ID='ami-2bb65342'
            
          You should see some progress information scroll by and finally you should see 
          a description of the key attributes of your running intance (dnsName and instanceId 
          are likely most important).
          
          Now lets connect to it with SSH (this may take a few tries, sometimes it takes a 
          minute for the new instance to respond to SSH):
          
            RUN (replace instance ID with the one reported in the previous step):
            
            cap ec2:instances:ssh INSTANCE_ID='i-xxxxxx'
          
          TADA!  You should be connected to your new instance in an SSH terminal.  When you are 
          done looking around type ^d (control-d) to exit the SSH shell.
          
          If you want to terminate your instance...
          
            RUN (replace the instance ID with the one reported in the previous step): 
            
            cap ec2:instances:terminate INSTANCE_ID='i-xxxxxx'
            
          You're done with your first amazon-ec2 and Capsize tutorial!
          
        Enjoy Capsize!
        
        MESSAGE
        
        puts message
        
      end
      
      desc <<-DESC
      Test your Capsize config.
      Run a simple test which will validate that your Capsize config 
      is setup and working properly when querying the Amazon EC2 servers.
      DESC
      task :check do
        
        begin
          capsize_ec2.describe_images(:owner_id => "amazon")
          puts "Congratulations!  Your credentials are verified and you are communicating properly with Amazon's EC2 service."
        rescue Exception => e
          puts "The test of your Capsize config failed with the following error: " + e
        end
        
      end
      
    end
    
  end
  
  
  # TODO : Should these be defined here? Doesn't that mean that every
  # time a deploy:setup is run these tasks are run also?  Can they
  # really be run in all circumstances without harm if repeated?
  # Lets discuss...
  #
  #callbacks to make this stuff happen
  #before "deploy:setup", "ec2:setup"
  #after "deploy:setup", "ec2:generate_config"
  
  
end
