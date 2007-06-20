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
  
  
  # CONSOLE METHODS
  #########################################
  
  
  def get_console_output(args = {})
    amazon = connect()
    options = {:instance_id => ""}.merge(args)
    amazon.get_console_output(:instance_id => options[:instance_id])
  end
  
  
  # KEYPAIR METHODS
  #########################################
  
  
  #describe your keypairs
  def describe_keypairs(args = {})
    amazon = connect()
    options = {:key_name => []}.merge(args)
    amazon.describe_keypairs(:key_name => options[:key_name])
  end
  
  
  #sets up a keypair named args[:key_name] and writes out the private key to args[:key_dir]
  def create_keypair(args = {})
    amazon = connect()
    
    # default keyname is the same as our appname, unless specifically overriden in capsize.yml
    # default key dir is config unless specifically overriden in capsize.yml
    args = {:key_name => "#{application}", :key_dir => "config"}.merge(args)
    args[:key_name] = @capsize_config.key_name unless @capsize_config.nil? || @capsize_config.key_name.nil? || @capsize_config.key_name.empty?
    args[:key_dir] = @capsize_config.key_dir unless @capsize_config.nil? || @capsize_config.key_dir.nil? || @capsize_config.key_dir.empty?
    
    # create the string that represents the full dir/name.key
    key_file = [args[:key_dir],args[:key_name]].join('/') + '.key'
    
    #verify key_name and key_dir are set
    raise Exception, "Keypair name required" if args[:key_name].nil? || args[:key_name].empty?
    raise Exception, "Keypair directory required" if args[:key_dir].nil? || args[:key_dir].empty?
    
    # Verify keypair doesn't already exist either remotely on EC2...
    unless amazon.describe_keypairs(:key_name => args[:key_name]).keySet.nil?
      raise Exception, "Sorry, a keypair with the name \"#{args[:key_name]}\" already exists on EC2."
    end
    
    # or exists locally.
    file_exists_message = <<-MESSAGE
    \n
    Warning! A keypair with the name \"#{key_file}\"
    already exists on your local filesytem.  You must remove it before trying to overwrite 
    again.  Warning! Removing keypairs associated with active instances will prevent you 
    from accessing them via SSH or Capistrano!!\n\n
    MESSAGE
    raise Exception, file_exists_message if File.exists?(key_file)
    
    #All is good, so we create a new keypair
    puts "Generating keypair... (this may take a moment)"
    private_key = amazon.create_keypair(:key_name => args[:key_name])
    puts "A keypair with the name \"#{private_key.keyName}\" has been generated..."
    
    # write private key to file
    File.open(key_file, 'w') do |file|
      file.write(private_key.keyMaterial)
      file.write("\n\nfingerprint:\n" + private_key.keyFingerprint)
      file.write("\n\nname:\n" + private_key.keyName)
    end
    puts "The generated private key has been saved in #{key_file}"
    
    # Cross platform CHMOD
    File.chmod 0600, key_file
    
  end
  
  
  # Deletes a keypair from EC2 and from the local filesystem
  def delete_keypair(args = {})
    amazon = connect()
    
    # TODO : Replace @capsize_config with calls to get()
    # default keyname is the same as our appname, unless specifically overriden in capsize.yml
    # default key dir is config unless specifically overriden in capsize.yml
    args = {:key_name => "#{application}", :key_dir => "config"}.merge(args)
    args[:key_name] = @capsize_config.key_name unless @capsize_config.nil? || @capsize_config.key_name.nil? || @capsize_config.key_name.empty?
    args[:key_dir] = @capsize_config.key_dir unless @capsize_config.nil? || @capsize_config.key_dir.nil? || @capsize_config.key_dir.empty?
    
    # create the string that represents the full dir/name.key
    key_file = [args[:key_dir],args[:key_name]].join('/') + '.key'
    
    raise Exception, "Keypair name required" if args[:key_name].nil?
    raise Exception, "Keypair dir is required" if args[:key_dir].nil?
    raise Exception, "Keypair \"#{args[:key_name]}\" does not exist on EC2." if amazon.describe_keypairs(:key_name => args[:key_name]).keySet.nil?
    
    amazon.delete_keypair(:key_name => args[:key_name])
    puts "Keypair \"#{args[:key_name]}\" deleted from EC2!"
    
    File.delete(key_file)
    puts "Keypair \"#{key_file}\" deleted from local file system!"
    
  end
  
  
  # IMAGE METHODS
  #########################################
  
  
  #describe the amazon machine images available for launch
  def describe_images(args = {})
    amazon = connect()
    options = {:image_id => [], :owner_id => [], :executable_by => []}.merge(args)
    amazon.describe_images(:image_id => options[:image_id], :owner_id => options[:owner_id], :executable_by => options[:executable_by])
  end
  
  
  # INSTANCE METHODS
  #########################################
  
  
  #returns information about instances owned by the user
  def describe_instances(args = {})
    amazon = connect()
    options = {:instance_id => []}.merge(args)
    amazon.describe_instances(:instance_id => options[:instance_id])
  end
  
  
  #run an EC2 instance
  #requires options[:keypair_name] and options[:image_id]
  #userdata may also passed to this instance with options[:user_data].
  #specifiy if this data is base_64 encoded with the boolean options[:base64_encoded]
  def run_instance(args = {})
    amazon = connect()
    
    #verify keypair_name and ami_id passed
    raise Exception, "Keypair name required" if args[:keypair_name].nil? || args[:keypair_name].empty?
    raise Exception, "AMI id required" if args[:image_id].nil? || args[:image_id].empty?
    
    response = amazon.run_instances(args)
    raise Exception, "Instance did not start" unless response.instancesSet.item[0].instanceState.name == "pending"
    instance_id = response.instancesSet.item[0].instanceId
    puts "Instance #{instance_id} Startup Pending"
    
    #loop checking for instance startup
    puts "Checking every 10 seconds to detect startup for up to 5 minutes"
    tries = 0
    begin
      instance = amazon.describe_instances(:instance_id => instance_id)
      raise "Server Not Running" unless instance.reservationSet.item[0].instancesSet.item[0].instanceState.name == "running"
      sleep 5
      return instance
    rescue
      puts "."
      sleep 10
      tries += 1
      retry unless tries == 35
      raise "Server Not Running"
    end
  end
  
  
  #reboot a running instance
  def reboot_instance(args = {})
    amazon = connect()
    options = {:instance_id => []}.merge(args)
    raise Exception, ":instance_id required" if options[:instance_id].nil?
    amazon.reboot_instances(:instance_id => options[:instance_id])
  end
  
  
  #terminates a running instance
  def terminate_instance(args = {})
    amazon = connect()
    options = {:instance_id => []}.merge(args)
    raise Exception, ":instance_id required" if options[:instance_id].nil?
    amazon.terminate_instances(:instance_id => options[:instance_id])
  end
  
  
  # SECURITY GROUP METHODS
  #########################################
  
  
  # Define firewall access rules for a specific security group.  Instances will inherit
  # the security group permissions based on the group they are assigned to.
  def authorize_ingress(args = {})
    amazon = connect()
    
    options = { :group_name => get(:group_name),
                :ip_protocol => 'tcp',
                :from_port => nil,
                :to_port => nil,
                :cidr_ip => '0.0.0.0/0',
                :source_security_group_name => "",
                :source_security_group_owner_id => "" }.merge(args)
    
    # Verify only that :group_name is passed.  This is the only REQUIRED parameter.
    # The others are optional and depend on what it is you are trying to 
    # do (CIDR based permissions vs. user/group pair permissions).  We let the EC2
    # service itself do the validations on the extra params and count on it to raise an exception
    # if it doesn't like the args passed.  We'll see an EC2::Exception class returned if so.
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
  def revoke_ingress(args = {})
    amazon = connect()
    
    options = { :group_name => get(:group_name),
                :ip_protocol => 'tcp',
                :from_port => nil,
                :to_port => nil,
                :cidr_ip => '0.0.0.0/0',
                :source_security_group_name => "",
                :source_security_group_owner_id => "" }.merge(args)
    
    # Verify only that :group_name is passed.  This is the only REQUIRED parameter.
    # The others are optional and depend on what it is you are trying to 
    # do (CIDR based permissions vs. user/group pair permissions).  We let the EC2
    # service itself do the validations on the extra params and count on it to raise an exception
    # if it doesn't like the args passed.  We'll see an EC2::Exception class returned if so.
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
  # call these from tasks with 'capsize.method_name'
  
  # returns an EC2::Base object
  #  * connect(args = {:access_key_id => "my_access_key_id", :secret_access_key => "my_secret_access_key"})
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
    
    begin
      return amazon = EC2::Base.new(:access_key_id => get(:aws_access_key_id), :secret_access_key => get(:aws_secret_access_key), :use_ssl => use_ssl)
    rescue Exception => e
      puts "Your EC2::Base authentication setup failed with the following message : " + e
      raise e
    end
  end
  
  # capsize.get(:symbol_name) checks for variables in several places, with this precedence (from low to high):
  # * default capistrano or capsize set variables (available with fetch())
  # * Set in config/secure_config.yml (overwrites previous)
  # * Set in config/capsize_config.yml (overwrites previous)
  # * Passed in as part of the command line params and available as ENV["SYMBOL_NAME"] (overwrites previous)
  # * If all of the above are nil, get response at a command line prompt for this variable
  #
  def get(symbol=nil)
    
    raise Exception if symbol.nil? || symbol.class != Symbol # TODO : Jesse: fixup exceptions in capsize
    
    # TODO : Jesse : Jesse, you talked about adding a simple caching layer so 
    # that calls to get() don't have to be avoided since they hit the filesytem
    # multiple times per call...  Thoughts?
    
    # populate the OpenStructs with contents of config files so we can query them.
    @secure_config = load_config(:config_file => "config/secure.yml")
    @capsize_config = load_config(:config_file => "config/capsize.yml")
    
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
    
    # finally if symbol name is still nil then prompt the user for it and set it.
    set symbol, fetch(symbol) {Capistrano::CLI.ui.ask("Please enter a value for #{symbol.to_s}: ")}
    
    # If we have a good set variable then return that variable, else send back a nil
    # if that's what we get and let the calling method either raise an exception 
    # or determine how to gracefully handle it.  We don't want to raise an exception every 
    # time a get fails.  nil might be a good answer for some questions? no?
    return fetch(symbol)
    
  end
  
  
  # load specified ":config_file => 'foo.yaml'" into a OpenStruct object and return it. 
  def load_config(args = {})
    args = {:config_file => ""}.merge(args)
    raise Exception, "Config file location required" if args[:config_file].nil? || args[:config_file].empty?
    
    if File.exist?(args[:config_file])
      config = OpenStruct.new(YAML.load_file(args[:config_file]))
      env_config =  OpenStruct.new(config.send(deploy_env))
      
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
  
  # TODO : A question for Jesse.  Can you elaborate on why its better for this to be here instead of in tasks.rb?
  # I see it does clean up tasks, but were not really making anythiing more DRY since we either have the code here
  # or there.  And we lose the consistency of this type of code all being in tasks.rb.
  # Doesn't really matter too much I guess, just wanted to learn from your thinking...
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