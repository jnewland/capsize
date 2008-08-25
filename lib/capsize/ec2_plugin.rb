module Capsize
  module CapsizeEC2
    include Capsize


    # HELPER METHODS
    #########################################


    def hostname_from_instance_id(instance_id = nil)
      raise Exception, "Instance ID required" if instance_id.nil? || instance_id.empty?

      amazon = connect()

      response = amazon.describe_instances(:instance_id => instance_id)
      return dns_name = response.reservationSet.item[0].instancesSet.item[0].dnsName
    end

    def hostnames_from_instance_ids(ids = [])
      ids.collect { |id| hostname_from_instance_id(id) }
    end

    def hostnames_from_group(group_name = nil)
      hostnames = []
      return hostnames if group_name.nil?
      instances = describe_instances
      return hostnames if instances.nil?
      return hostnames if instances.reservationSet.nil?
      instances.reservationSet.item.each do |reservation|
        hostname = nil
        in_group = false
        running = false
        unless reservation.groupSet.nil?
          reservation.groupSet.item.each do |group|
            in_group = group.groupId == group_name
          end
        end

        unless reservation.instancesSet.nil?
          reservation.instancesSet.item.each do |instance|
            hostname = instance.dnsName
            running = (!instance.instanceState.nil? && (instance.instanceState.name == "running"))
          end
        end
        hostnames << hostname if in_group and running
      end
      return hostnames
    end

    def role_from_security_group(role, security_group, *args)
      options = args.last.is_a?(Hash) ? args.pop : {}
      options = {:user => 'root', :ssh_options => { :keys => [capsize_ec2.get_key_file] }}.merge(options)
      role(role, options) do
        hostnames_from_group(security_group)
      end
    end

    # build the key file path from key_dir and key_file
    def get_key_file(options = {})
      options = {:key_dir => nil, :key_name => nil}.merge(options)
      key_dir = options[:key_dir] || get(:key_dir) || get(:capsize_secure_config_dir)
      key_name = options[:key_name] || get(:key_name)
      return key_file = [key_dir, "id_rsa-" + key_name].join('/')
    end


    # CONSOLE METHODS
    #########################################


    def get_console_output(options = {})
      amazon = connect()
      options = {:instance_id => ""}.merge(options)
      amazon.get_console_output(:instance_id => options[:instance_id])
    end


    # KEYPAIR METHODS
    #########################################


    #describe your keypairs
    def describe_keypairs(options = {})
      amazon = connect()
      options = {:key_name => []}.merge(options)
      amazon.describe_keypairs(:key_name => options[:key_name])
    end

    #sets up a keypair named options[:key_name] and writes out the private key to options[:key_dir]
    def create_keypair(options = {})
      amazon = connect()

      # default key_name is the same as our appname, unless specifically overriden in capsize.yml
      # default key_dir is set in the :capsize_config_dir variable
      options = {:key_name => nil, :key_dir => nil}.merge(options)

      options[:key_name] = options[:key_name] || get(:key_name)
      options[:key_dir] = options[:key_dir] || get(:key_dir) || get(:capsize_secure_config_dir)

      #verify key_name and key_dir are set
      raise Exception, "Keypair name required" if options[:key_name].nil? || options[:key_name].empty?
      raise Exception, "Keypair directory required" if options[:key_dir].nil? || options[:key_dir].empty?

      key_file = get_key_file(:key_name => options[:key_name], :key_dir => options[:key_dir])

      # Verify local private key file doesn't already exist...
      file_exists_message = <<-MESSAGE
      \n
      Warning! A keypair with the name \"#{key_file}\"
      already exists on your local filesytem.   You must remove it before trying to overwrite
      again.  Warning! Removing keypairs associated with active instances will prevent you
      from accessing them via SSH or Capistrano!!\n\n
      MESSAGE
      raise Exception, file_exists_message if File.exists?(key_file)

      # Try to create the new keypair
      begin
        private_key = amazon.create_keypair(:key_name => options[:key_name])
      rescue EC2::InvalidKeyPairDuplicate
        # keypair already exists with this :key_name
        # Re-raising will provide a useful message, so we don't need to
        raise
      rescue EC2::InvalidKeyPairNotFound
        # this is a new keypair, continue
      end

      # write private key to file
      File.open(key_file, 'w') do |file|
        file.write(private_key.keyMaterial)
      end

      # Cross platform CHMOD, make the file owner +rw, group and other -all
      File.chmod 0600, key_file
      return [key_name, key_file]
    end


    # TODO : Is there a way to extract the 'puts' calls from here and make this have less 'view' code?
    # Deletes a keypair from EC2 and from the local filesystem
    def delete_keypair(options = {})
      amazon = connect()

      options = {:key_name => nil, :key_dir => nil}.merge(options)

      options[:key_name] = options[:key_name] || get(:key_name)
      options[:key_dir] = options[:key_dir] || get(:key_dir) || get(:capsize_secure_config_dir)

      raise Exception, "Keypair name required" if options[:key_name].nil? || options[:key_name].empty?
      raise Exception, "Keypair directory required" if options[:key_dir].nil? || options[:key_dir].empty?
      raise Exception, "Keypair \"#{options[:key_name]}\" does not exist on EC2." if amazon.describe_keypairs(:key_name => options[:key_name]).keySet.nil?

      # delete the keypair from the amazon EC2 servers
      amazon.delete_keypair(:key_name => options[:key_name])
      puts "Keypair \"#{options[:key_name]}\" deleted from EC2!"

      begin
        # determine the local key file name and delete it
        key_file = get_key_file(:key_name => options[:key_name])
        File.delete(key_file)
      rescue
        puts "Keypair \"#{key_file}\" not found on the local filesystem."
      else
        puts "Keypair \"#{key_file}\" deleted from local file system!"
      end
    end


    # IMAGE METHODS
    #########################################


    #describe the amazon machine images available for launch
    # Even though the amazon-ec2 library allows us to pass in an array of image_id's,
    # owner_id's, or executable_by's we restrict Capsize usage to passing in a String
    # with a single value.
    def describe_images(options = {})
      amazon = connect()

      options = {:image_id => nil, :owner_id => nil, :executable_by => nil}.merge(options)

      options[:image_id] = options[:image_id] || get(:image_id) || ""
      options[:owner_id] = options[:owner_id] || get(:owner_id) || ""
      options[:executable_by] = options[:executable_by] || get(:executable_by) || ""

      amazon.describe_images(:image_id => options[:image_id], :owner_id => options[:owner_id], :executable_by => options[:executable_by])

    end


    # INSTANCE METHODS
    #########################################


    #returns information about instances owned by the user
    def describe_instances(options = {})
      amazon = connect()
      options = {:instance_id => []}.merge(options)
      amazon.describe_instances(:instance_id => options[:instance_id])
    end


    # Run EC2 instance(s)
    # TODO : Deal with starting multiple instances! Now only single instances are properly handled.
    def run_instance(options = {})
      amazon = connect()

      options = { :image_id => get(:image_id),
                  :min_count => get(:min_count),
                  :max_count => get(:max_count),
                  :key_name => nil,
                  :group_name => nil,
                  :user_data => get(:user_data),
                  :addressing_type => get(:addressing_type),
                  :instance_type => get(:instance_type),
                  :availability_zone => get(:availability_zone)
                }.merge(options)

      # What security group should we run as?
      options[:group_id] = (options[:group_name] || get(:group_name) || "").split(',')

      # We want to run the new instance using our public/private keypair if
      # one is defined for this application or of the user has explicitly passed
      # in a key_name as a parameter.   Only allow use of application name keyname if
      # the <application> name is defined on EC2 as a key_name, AND we have the local
      # private key stored in the config dir.

      # override application key_name if the user provided one in config or on the command line
      options[:key_name] = options[:key_name] || get(:key_name)

      # key_dir defaults to same as :capsize_config_dir variable
      options[:key_dir] = options[:key_dir] || get(:key_dir) || get(:capsize_secure_config_dir)

      # determine the local key file name and delete it
      key_file = get_key_file(:key_name => options[:key_name], :key_dir => options[:key_dir])

      # don't let them go further if there is no private key present.
      raise Exception, "Private key is not present in #{key_file}.\nPlease generate one with 'cap ec2:keypairs:create' or specify a different KEY_NAME." unless File.exists?(key_file)

      # Verify image_id, min_count, and max_count are present as these are required
      raise Exception, "image_id (ami-) required" if options[:image_id].nil? || options[:image_id].empty?
      raise Exception, "min_count is required" if options[:min_count].nil?
      raise Exception, "max_count is required" if options[:max_count].nil?

      # Start instance(s)!
      response = amazon.run_instances(options)

      instance_id = response.instancesSet.item[0].instanceId
      puts "Instance #{instance_id} startup in progress"
      
      #set scope outside of block
      instance = nil

      #loop checking for confirmation that instance is running
      tries = 0
      begin
        instance = amazon.describe_instances(:instance_id => instance_id)
        raise "Server Not Running" unless instance.reservationSet.item[0].instancesSet.item[0].instanceState.name == "running"
        puts ""
        puts "Instance #{instance_id} entered state 'running'"
      rescue
        $stdout.print '.'
        sleep(10)
        tries += 1
        retry unless tries == 35
        raise "Instance #{instance_id} never moved to state 'running'!"
      end

      #loop waiting to get the public key
      tries = 0
      begin
        require 'timeout'
        begin
          Timeout::timeout(5) do
            system("ssh -o StrictHostKeyChecking=no -o PasswordAuthentication=no -i #{get_key_file} root@#{hostname_from_instance_id(instance_id)} echo success") or raise "SSH Auth Failure"
          end
        rescue Timeout::Error
          raise "SSH timed out..."
        end
        puts ""
        puts "SSH is up! Grabbing the public key..."
        if system "scp -o StrictHostKeyChecking=no -i #{get_key_file} root@#{hostname_from_instance_id(instance_id)}:/mnt/openssh_id.pub #{get_key_file}.pub"
          puts "Public key saved at #{get_key_file}.pub"
        else
          puts "Error grabbing public key"
        end
      rescue Exception => e
        $stdout.print '.'
        sleep(10)
        tries += 1
        retry unless tries == 35
        puts "We couldn't ever SSH in!"
      end
      
      #scripts
      if File.exists?(fetch(:capsize_config_dir)+"/scripts")
        begin
          instance = amazon.describe_instances(:instance_id => instance_id)
          instance.reservationSet.item.first.groupSet.item.map { |g| g.groupId }.sort.each do |group|
            script_path = fetch(:capsize_config_dir)+"/scripts/#{group}"
            if File.exists?(script_path)
              begin
                puts "Found script for security group #{group}, running"
                system("scp -o StrictHostKeyChecking=no -i #{get_key_file} #{script_path} root@#{hostname_from_instance_id(instance_id)}:/tmp/") or raise "SCP ERROR"
                system("ssh -o StrictHostKeyChecking=no -i #{get_key_file} root@#{hostname_from_instance_id(instance_id)} chmod o+x /tmp/#{group}") or raise "Error changing script permissions"
                system("ssh -o StrictHostKeyChecking=no -i #{get_key_file} root@#{hostname_from_instance_id(instance_id)} /tmp/#{group}") or raise "Error running script"
              rescue Exception => e
                puts e
              end
            end
          end
        rescue Exception => e
          puts e
        end
      end

      return instance
    end


    #reboot a running instance
    def reboot_instance(options = {})
      amazon = connect()
      options = {:instance_id => []}.merge(options)
      raise Exception, ":instance_id required" if options[:instance_id].nil?
      amazon.reboot_instances(:instance_id => options[:instance_id])
    end


    #terminates a running instance
    def terminate_instance(options = {})
      amazon = connect()
      options = {:instance_id => []}.merge(options)
      raise Exception, ":instance_id required" if options[:instance_id].nil?
      amazon.terminate_instances(:instance_id => options[:instance_id])
    end


    # SECURITY GROUP METHODS
    #########################################


    def create_security_group(options = {})
      amazon = connect()

      # default group_name is the same as our appname, unless specifically overriden in capsize.yml
      # default group_description is set in the :group_description variable
      options = {:group_name => nil, :group_description => nil}.merge(options)

      options[:group_name] = options[:group_name] || get(:group_name)
      options[:group_description] = options[:group_description] || get(:group_description)

      raise Exception, "Group name required" if options[:group_name].nil? || options[:group_name].empty?
      raise Exception, "Group description required" if options[:group_description].nil? || options[:group_description].empty?

      amazon.create_security_group(:group_name => options[:group_name], :group_description => options[:group_description])

    end


    #describe your security groups
    def describe_security_groups(options = {})
      amazon = connect()
      options = {:group_name => nil}.merge(options)
      options[:group_name] = options[:group_name] || get(:group_name) || ""
      amazon.describe_security_groups(:group_name => options[:group_name])
    end


    def delete_security_group(options = {})
      amazon = connect()

      # default group_name is the same as our appname, unless specifically overriden in capsize.yml
      options = {:group_name => nil}.merge(options)

      options[:group_name] = options[:group_name] || get(:group_name)

      raise Exception, "Group name required" if options[:group_name].nil? || options[:group_name].empty?

      amazon.delete_security_group(:group_name => options[:group_name])

    end


    # Define firewall access rules for a specific security group.   Instances will inherit
    # the security group permissions based on the group they are assigned to.
    def authorize_ingress(options = {})
      amazon = connect()

      options = { :group_name => nil,
                  :ip_protocol => get(:ip_protocol),
                  :from_port => get(:from_port),
                  :to_port => get(:to_port),
                  :cidr_ip => get(:cidr_ip),
                  :source_security_group_name => get(:source_security_group_name),
                  :source_security_group_owner_id => get(:source_security_group_owner_id) }.merge(options)

      options[:group_name] = options[:group_name] || get(:group_name)

      # Verify only that :group_name is passed.   This is the only REQUIRED parameter.
      # The others are optional and depend on what it is you are trying to
      # do (CIDR based permissions vs. user/group pair permissions).  We let the EC2
      # service itself do the validations on the extra params and count on it to raise an exception
      # if it doesn't like the options passed.  We'll see an EC2::Exception class returned if so.
      raise Exception, "You must specify a :group_name" if options[:group_name].nil? || options[:group_name].empty?

      # set the :to_port to the same value as :from_port if :to_port was not explicitly defined.
      unless options[:from_port].nil? || options[:from_port].empty?
        set :to_port, options[:from_port] if options[:to_port].nil? || options[:to_port].empty?
        options[:to_port] = to_port if options[:to_port].nil? || options[:to_port].empty?
      end
      
      #if source_security_group_name and source_security_group_owner_id are specified, unset the incompatible options
      if !options[:source_security_group_name].nil? && !options[:source_security_group_owner_id].nil?
        options.delete(:ip_protocol)
        options.delete(:from_port)
        options.delete(:to_port)
        options.delete(:cidr_ip)        
      end

      amazon.authorize_security_group_ingress(options)

    end


    # Revoke firewall access rules for a specific security group.   Instances will inherit
    # the security group permissions based on the group they are assigned to.
    def revoke_ingress(options = {})
      amazon = connect()

      options = { :group_name => nil,
                  :ip_protocol => get(:ip_protocol),
                  :from_port => get(:from_port),
                  :to_port => get(:to_port),
                  :cidr_ip => get(:cidr_ip),
                  :source_security_group_name => get(:source_security_group_name),
                  :source_security_group_owner_id => get(:source_security_group_owner_id) }.merge(options)

      options[:group_name] = options[:group_name] || get(:group_name)

      # Verify only that :group_name is passed.   This is the only REQUIRED parameter.
      # The others are optional and depend on what it is you are trying to
      # do (CIDR based permissions vs. user/group pair permissions).  We let the EC2
      # service itself do the validations on the extra params and count on it to raise an exception
      # if it doesn't like the options passed.  We'll see an EC2::Exception class returned if so.
      raise Exception, "You must specify a :group_name" if options[:group_name].nil? || options[:group_name].empty?

      # set the :to_port to the same value as :from_port if :to_port was not explicitly defined.
      unless options[:from_port].nil? || options[:from_port].empty?
        set :to_port, options[:from_port] if options[:to_port].nil? || options[:to_port].empty?
        options[:to_port] = to_port if options[:to_port].nil? || options[:to_port].empty?
      end
      
      #if source_security_group_name and source_security_group_owner_id are specified, unset the incompatible options
      if !options[:source_security_group_name].nil? && !options[:source_security_group_owner_id].nil?
        options.delete(:ip_protocol)
        options.delete(:from_port)
        options.delete(:to_port)
        options.delete(:cidr_ip)        
      end

      amazon.revoke_security_group_ingress(options)

    end

    # ELASTIC IP ADDRESS METHODS
    #########################################

    # returns information about elastic IP addresses owned by the user
    def describe_addresses(options = {})
      amazon = connect()
      options = {:public_ip => []}.merge(options)
      amazon.describe_addresses(:public_ip => options[:public_ip])
    end
    
    # allocate an elastic IP address for use with this account
    def allocate_address
      amazon = connect()
      amazon.allocate_address
    end
    
    # release an elastic IP address from this account
    def release_address(options)
      amazon = connect()
      amazon.release_address(:public_ip => options[:public_ip])
    end
    
    # associate an elastic IP address to an instance
    def associate_address(options)
      amazon = connect()
      amazon.associate_address(:public_ip => options[:public_ip], :instance_id => options[:instance_id])
    end
    
    # disassociate an elastic IP address from whatever instance it may be assigned to
    def disassociate_address(options)
      amazon = connect()
      amazon.disassociate_address(:public_ip => options[:public_ip])
    end


    # CAPSIZE HELPER METHODS
    #########################################
    # call these from tasks.rb with 'capsize.method_name'
    # returns an EC2::Base object
    def connect()

      # get the :use_ssl value from the config pool and set it if its available
      # this will allow users to globally override whether or not their connection
      # is made via SSL in their config files or deploy.rb.   Of course default to using SSL.
      case get(:use_ssl)
      when true, nil
        set :use_ssl, true
      when false
        set :use_ssl, false
      else
        raise Exception, "You have an invalid value in your config for :use_ssl. Must be 'true' or 'false'."
      end

      # Optimized so we don't read the config files six times just to connect.
      # Read once, set it, and re-use what we get back...
      set :aws_access_key_id, get(:aws_access_key_id)
      set :aws_secret_access_key, get(:aws_secret_access_key)

      raise Exception, "You must have an :aws_access_key_id defined in your config." if fetch(:aws_access_key_id).nil? || fetch(:aws_access_key_id).empty?
      raise Exception, "You must have an :aws_secret_access_key defined in your config." if fetch(:aws_secret_access_key).nil? || fetch(:aws_secret_access_key).empty?

      begin
        return amazon = EC2::Base.new(:access_key_id => get(:aws_access_key_id), :secret_access_key => get(:aws_secret_access_key), :use_ssl => use_ssl)
      rescue Exception => e
        puts "Your EC2::Base authentication setup failed with the following message : " + e
        raise e
      end
    end

    # TODO : Finish this...
    # accept a Response object and provide screen output of the key data from
    # this response that needs to be permanently added to the users deploy.rb
    # and/or Capsize config files.
    def print_config_instructions(response = nil)

      raise Exception, "run_instances Response object expected" if response.nil?

      dns_name = response.reservationSet.item[0].instancesSet.item[0].dnsName

      puts "\n\nConfiguration Instructions:\n"

      config_help <<-HELP
      In order to control this new server instance from Capsize and Capistrano in the
      future you will need to store some critical instance information in your
      deploy.rb configuration file.   Please add something like the following to
      the appropriate places in your config/deploy.rb file.   Of course you may need to
      modify this information to suite your circumstances, this is only an example.
      \n\n
      config/deploy.rb
      --
      HELP

      puts config_help

      puts "role :app, #{dns_name}"
      puts "role :web, #{dns_name}"
      puts "role :db, #{dns_name}, :primary => true"

    end

    # Keeping DRY.  This is called from run instances and describe instances.
    def print_instance_description(result = nil)
      puts "" if result.nil?
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
                puts "  instancesSet:instanceType = " + instance.instanceType unless instance.instanceType.nil?
                puts "  instancesSet:imageId = " + instance.imageId unless instance.imageId.nil?
                puts "  instancesSet:privateDnsName = " + instance.privateDnsName unless instance.privateDnsName.nil?
                puts "  instancesSet:dnsName = " + instance.dnsName unless instance.dnsName.nil?
                puts "  instancesSet:reason = " + instance.reason unless instance.reason.nil?
                puts "  instancesSet:launchTime = " + instance.launchTime unless instance.launchTime.nil?
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
    
    # print the result of an describe_addresses
    def print_address_description(result = nil)
      puts "" if result.nil?
      unless result.addressesSet.nil?
        result.addressesSet.item.each do |item|
          puts "addressesSet:publicIp = " + item.publicIp unless item.publicIp.nil?
          puts "addressesSet:instanceId = " + (item.instanceId ? item.instanceId : '(unassociated)')
          puts ""
        end
      else
        puts "You don't have any elastic IP addresses. Run 'cap ec2:addresses:allocate' to acquire one."
      end
    end
    
  end
end
Capistrano.plugin :capsize_ec2, Capsize::CapsizeEC2