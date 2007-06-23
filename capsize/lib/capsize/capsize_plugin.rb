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

module CapsizePlugin
  
  
  # HELPER METHODS
  #########################################
  
  
  def get_dns_name_from_instance_id(options = {})
    amazon = connect()
    options = {:instance_id => ""}.merge(options)
    
    raise Exception, "Instance ID required" if options[:instance_id].nil? || options[:instance_id].empty?
    
    response = amazon.describe_instances(:instance_id => options[:instance_id])
    return dns_name = response.reservationSet.item[0].instancesSet.item[0].dnsName
  end
  
  
  # build the key file path from key_dir and key_file
  def get_key_file(options = {})
    options = {:key_dir => nil, :key_name => nil}.merge(options)
    key_dir = options[:key_dir] || get(:key_dir) || get(:capsize_secure_config_dir)
    key_name = options[:key_name] || get(:key_name) || "#{application}"
    return key_file = [key_dir, key_name].join('/') + '.key'
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
  
  
  # TODO : Is there a way to extract the 'puts' calls from here and make this have less 'view' code?
  #sets up a keypair named options[:key_name] and writes out the private key to options[:key_dir]
  def create_keypair(options = {})
    amazon = connect()
    
    # default key_name is the same as our appname, unless specifically overriden in capsize.yml
    # default key_dir is set in the :capsize_config_dir variable
    options = {:key_name => nil, :key_dir => nil}.merge(options)
    
    options[:key_name] = options[:key_name] || get(:key_name) || "#{application}"
    options[:key_dir] = options[:key_dir] || get(:key_dir) || get(:capsize_secure_config_dir)
    
    #verify key_name and key_dir are set
    raise Exception, "Keypair name required" if options[:key_name].nil? || options[:key_name].empty?
    raise Exception, "Keypair directory required" if options[:key_dir].nil? || options[:key_dir].empty?
    
    # determine the local key file name and delete it
    key_file = get_key_file(:key_name => options[:key_name], :key_dir => options[:key_dir])
    
    # Verify keypair doesn't already exist on EC2 servers...
    unless amazon.describe_keypairs(:key_name => options[:key_name]).keySet.nil?
      raise Exception, "Sorry, a keypair with the name \"#{options[:key_name]}\" already exists on EC2."
    end
    
    # and doesn't exist locally either...
    file_exists_message = <<-MESSAGE
    \n
    Warning! A keypair with the name \"#{key_file}\"
    already exists on your local filesytem.  You must remove it before trying to overwrite 
    again.  Warning! Removing keypairs associated with active instances will prevent you 
    from accessing them via SSH or Capistrano!!\n\n
    MESSAGE
    raise Exception, file_exists_message if File.exists?(key_file)
    
    #All is good, so we create the new keypair
    puts "Generating keypair... (this may take a few seconds)"
    private_key = amazon.create_keypair(:key_name => options[:key_name])
    puts "A keypair with the name \"#{private_key.keyName}\" has been generated..."
    
    # write private key to file
    File.open(key_file, 'w') do |file|
      file.write(private_key.keyMaterial)
    end
    puts "The generated private key has been saved in #{key_file}"
    
    # Cross platform CHMOD, make the file owner +rw, group and other -all
    File.chmod 0600, key_file
    
  end
  
  
  # TODO : Is there a way to extract the 'puts' calls from here and make this have less 'view' code?
  # Deletes a keypair from EC2 and from the local filesystem
  def delete_keypair(options = {})
    amazon = connect()
    
    options = {:key_name => nil, :key_dir => nil}.merge(options)
    
    options[:key_name] = options[:key_name] || get(:key_name) || "#{application}"
    options[:key_dir] = options[:key_dir] || get(:key_dir) || get(:capsize_secure_config_dir)
    
    raise Exception, "Keypair name required" if options[:key_name].nil? || options[:key_name].empty?
    raise Exception, "Keypair directory required" if options[:key_dir].nil? || options[:key_dir].empty?
    raise Exception, "Keypair \"#{options[:key_name]}\" does not exist on EC2." if amazon.describe_keypairs(:key_name => options[:key_name]).keySet.nil?
    
    # delete the keypair from the amazon EC2 servers
    amazon.delete_keypair(:key_name => options[:key_name])
    puts "Keypair \"#{options[:key_name]}\" deleted from EC2!"
    
    # determine the local key file name and delete it
    key_file = get_key_file(:key_name => options[:key_name])
    File.delete(key_file)
    puts "Keypair \"#{key_file}\" deleted from local file system!"
    
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
  # TODO : Deal with starting multiple instances!  Now only single instances are properly handled.
  # TODO : Is there a way to extract the 'puts' calls from here and make this have less 'view' code?
  # TODO : Make sure that the run instance uses both the app specific keypair, and the app specific security group when starting, if they exist
  def run_instance(options = {})
    amazon = connect()
    
    options = { :image_id => get(:image_id),
                :min_count => get(:min_count),
                :max_count => get(:max_count),
                :key_name => nil,
                :group_name => get(:group_name),
                :user_data => get(:user_data),
                :addressing_type => get(:addressing_type)
              }.merge(options)
    
    # We want to run the new instance using our public/private keypair if
    # one is defined for this application or of the user has explicitly passed
    # in a key_name as a parameter.  Only allow use of application name keyname if
    # the <application> name is defined on EC2 as a key_name, AND we have the local
    # private key stored in the config dir.
    
    # override application key_name if the user provided one in config or on the command line
    options[:key_name] = options[:key_name] || get(:key_name) || "#{application}"
    
    # key_dir defaults to same as :capsize_config_dir variable
    options[:key_dir] = options[:key_dir] || get(:key_dir) || get(:capsize_secure_config_dir)
    
    # determine the local key file name and delete it
    key_file = get_key_file(:key_name => options[:key_name], :key_dir => options[:key_dir])
    
    # don't let them go further if there is no private key present.
    raise Exception, "Private key is not present in #{key_file}.\nPlease generate one with 'cap ec2:keypairs:create' or specify a different KEY_NAME." unless File.exists?(key_file)
    
    # Verify image_id, min_count, and max_count are present as these are required
    raise Exception, "Image ID (ami-) required" if options[:image_id].nil? || options[:image_id].empty?
    raise Exception, "Min count is required" if options[:min_count].nil?
    raise Exception, "Max count is required" if options[:max_count].nil?
    
    # Start instance(s)!
    response = amazon.run_instances(options)
    
    instance_id = response.instancesSet.item[0].instanceId
    puts "Instance #{instance_id} startup in progress..."
    
    # loop checking for instance pending notification
    puts "Checking every 10 seconds to detect startup state of 'pending' for up to 5 minutes"
    tries = 0
    begin
      instance = amazon.describe_instances(:instance_id => instance_id)
      raise "Waiting." unless response.instancesSet.item[0].instanceState.name == "pending"
      puts "Instance #{instance_id} is 'pending'"
    rescue
      puts "."
      sleep(10)
      tries += 1
      retry unless tries == 35
      raise "Instance #{instance_id} never moved to state 'pending'!"
    end
    
    #loop checking for confirmation that instance is running
    puts "Checking every 10 seconds to detect startup state of 'running' for up to 5 minutes"
    tries = 0
    begin
      instance = amazon.describe_instances(:instance_id => instance_id)
      raise "Server Not Running" unless instance.reservationSet.item[0].instancesSet.item[0].instanceState.name == "running"
      puts "Instance #{instance_id} is 'running'"
      return instance
    rescue
      puts "."
      sleep(10)
      tries += 1
      retry unless tries == 35
      raise "Instance #{instance_id} never moved to state 'running'!"
    end
    
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
    
    options[:group_name] = options[:group_name] || get(:group_name) || "#{application}"
    options[:group_description] = options[:group_description] || get(:group_description) || "#{application}"
    
    raise Exception, "Group name required" if options[:group_name].nil? || options[:group_name].empty?
    raise Exception, "Group description required" if options[:group_description].nil? || options[:group_description].empty?
    
    amazon.create_security_group(:group_name => options[:group_name], :group_description => options[:group_description])
    
  end
  
  
  def delete_security_group(options = {})
    amazon = connect()
    
    # default group_name is the same as our appname, unless specifically overriden in capsize.yml
    options = {:group_name => nil}.merge(options)
    
    options[:group_name] = options[:group_name] || get(:group_name) || "#{application}"
    
    raise Exception, "Group name required" if options[:group_name].nil? || options[:group_name].empty?
    
    amazon.delete_security_group(:group_name => options[:group_name])
    
  end
  
  
  # Define firewall access rules for a specific security group.  Instances will inherit
  # the security group permissions based on the group they are assigned to.
  def authorize_ingress(options = {})
    amazon = connect()
    
    options = { :group_name => get(:group_name),
                :ip_protocol => get(:ip_protocol),
                :from_port => get(:from_port),
                :to_port => get(:to_port),
                :cidr_ip => get(:cidr_ip),
                :source_security_group_name => get(:source_security_group_name),
                :source_security_group_owner_id => get(:source_security_group_owner_id) }.merge(options)
    
    # Verify only that :group_name is passed.  This is the only REQUIRED parameter.
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
    
    amazon.authorize_security_group_ingress(options)
    
  end
  
  
  # Revoke firewall access rules for a specific security group.  Instances will inherit
  # the security group permissions based on the group they are assigned to.
  def revoke_ingress(options = {})
    amazon = connect()
    
    options = { :group_name => get(:group_name),
                :ip_protocol => get(:ip_protocol),
                :from_port => get(:from_port),
                :to_port => get(:to_port),
                :cidr_ip => get(:cidr_ip),
                :source_security_group_name => get(:source_security_group_name),
                :source_security_group_owner_id => get(:source_security_group_owner_id) }.merge(options)
    
    # Verify only that :group_name is passed.  This is the only REQUIRED parameter.
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
    
    amazon.revoke_security_group_ingress(options)
    
  end
  
  
  # CAPSIZE HELPER METHODS
  #########################################
  # call these from tasks.rb with 'capsize.method_name'
  # returns an EC2::Base object
  def connect()
    
    # get the :use_ssl value from the config pool and set it if its available
    # this will allow users to globally override whether or not their connection
    # is made via SSL in their config files or deploy.rb.  Of course default to using SSL.
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
    
    # TODO : Do we need this begin/rescue here?  Or just let each calling method/task rescue?  This would also get the 'puts' out of this file.
    begin
      return amazon = EC2::Base.new(:access_key_id => get(:aws_access_key_id), :secret_access_key => get(:aws_secret_access_key), :use_ssl => use_ssl)
    rescue Exception => e
      puts "Your EC2::Base authentication setup failed with the following message : " + e
      raise e
    end
  end
  
  # capsize.get(:symbol_name) checks for variables in several places, with this precedence (from low to high):
  # * default capistrano or capsize set variables (available with fetch())
  # * Set in :capsize_config_dir/:capsize_config_file_name (overwrites previous)
  # * Set in :capsize_config_dir/:capsize_secure_config_file_name (overwrites previous)
  # * Passed in as part of the command line params and available as ENV["SYMBOL_NAME"] (overwrites previous)
  # * If all of the above are nil, get response at a command line prompt for this variable
  #
  def get(symbol=nil)
    
    raise Exception if symbol.nil? || symbol.class != Symbol # TODO : Jesse: fixup exceptions in capsize
    
    # TODO : Jesse : Jesse, you talked about adding a simple caching layer so 
    # that calls to get() don't have to be avoided since they hit the filesystem
    # multiple times per call...  Thoughts?
    
    # populate the OpenStructs with contents of config files so we can query them.
    @capsize_config = load_config(:config_file => "#{fetch(:capsize_config_dir)}/#{fetch(:capsize_config_file_name)}")
    @secure_config = load_config(:config_file => "#{fetch(:capsize_secure_config_dir)}/#{fetch(:capsize_secure_config_file_name)}")
    
    # fetch var from default capsize or default capistrano config vars, 
    # and if it doesn't exist set it to nil
    set symbol, fetch(symbol, nil)
    
    # if symbol exists as a var in the secure config, then set it to that
    # overriding default cap or capsize config vars
    if @secure_config.respond_to?(symbol)
      set symbol, @secure_config.send(symbol)
    end
    
    # if symbol exists as a var in the standard capsize config, then set it to that
    # overriding secure config vars
    if @capsize_config.respond_to?(symbol)
      set symbol, @capsize_config.send(symbol)
    end
    
    # if ENV["SYMBOL_NAME"] isn't nil set it to ENV["SYMBOL_NAME"]
    # ENV vars passed on the command line override any previously defined vars
    unless ENV[symbol.to_s.upcase].nil?
      set symbol, ENV[symbol.to_s.upcase]
    end
    
    # TODO : Determine whether to keep this.  While it seems nice it also interferes
    # with the easy ability to try to get() some variable anywhere in the app and know that
    # if it does not exist we'll get a nil back.  Having this prompt every time can be
    # very annoying and bad in non-interactive situations.  Maybe its better to just
    # raise an exception if the user is not providing all that we need either in config
    # files or on the command line.
    #
    # finally if symbol name is still nil then prompt the user for it and set it.
    #unless fetch(symbol)
    #  set symbol, Capistrano::CLI.ui.ask("Please enter a value for #{symbol.to_s}: ")
    #end
    
    # If we have a good set variable then return that variable, else send back a nil
    # if that's what we get and let the calling method either raise an exception 
    # or determine how to gracefully handle it.  We don't want to raise an exception every 
    # time a get fails.  nil might be a good answer for some questions? no?
    return fetch(symbol)
    
  end
  
  
  # load specified ":config_file => 'foo.yaml'" into a OpenStruct object and return it. 
  def load_config(options = {})
    options = {:config_file => ""}.merge(options)
    
    raise Exception, "Config file location required" if options[:config_file].nil? || options[:config_file].empty?
    
    if File.exist?(options[:config_file])
      
      # try to load the yaml config file
      begin
        config = OpenStruct.new(YAML.load_file(options[:config_file]))
        env_config =  OpenStruct.new(config.send(deploy_env))
      rescue Exception => e
        env_config = nil
      end
      
      # Send back an empty OpenStruct if we can't load the config file.
      # config files are not required!  Want to avoid method calls on nil
      # if there are no config files to load.
      if env_config.nil?
        return OpenStruct.new
      else
        return env_config
      end
      
    end
  end
  
  # TODO : I was thinking that maybe we can have a way to serialize the instance info for instances
  # that we have started through this tool.  So for example, when you start an instance we can push
  # its instance ID onto an object and then serialize it to yaml in the config dir.  This way we can
  # maintain a sort of database without any of the dependencies of a DB?  Not really fleshed out.  Just
  # putting this here as a reminder as something to think about??
  
  
  # TODO : Should these methods with puts in them be in here or in the tasks.rb?
  
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
    deploy.rb configuration file.  Please add something like the following to 
    the appropriate places in your config/deploy.rb file.  Of course you may need to 
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
Capistrano.plugin :capsize, CapsizePlugin