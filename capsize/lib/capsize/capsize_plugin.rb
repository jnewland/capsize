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
    args[:key_name] = @capsize_config.key_name unless @capsize_config.key_name.nil? || @capsize_config.key_name.empty?
    args[:key_dir] = @capsize_config.key_dir unless @capsize_config.key_dir.nil? || @capsize_config.key_dir.empty?
    
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
    
    # default keyname is the same as our appname, unless specifically overriden in capsize.yml
    # default key dir is config unless specifically overriden in capsize.yml
    args = {:key_name => "#{application}", :key_dir => "config"}.merge(args)
    args[:key_name] = @capsize_config.key_name unless @capsize_config.key_name.nil? || @capsize_config.key_name.empty?
    args[:key_dir] = @capsize_config.key_dir unless @capsize_config.key_dir.nil? || @capsize_config.key_dir.empty?
    
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
  
  
  # TODO : GET THIS METHOD WORKING WITH NEW AMAZON-EC2
  # TODO : ADD A REBOOT TASK
  # def reboot_instances(options= {:instance_ids => []})
  #   puts "not yet implmented"
  # end
  
  
  # TODO : GET THIS METHOD WORKING WITH NEW AMAZON-EC2
  #run an EC2 instance
  #
  #requires options[:keypair_name] and options[:ami_id]
  #
  #userdata may also passed to this instance with options[:user_data].
  #specifiy if this data is base_64 encoded with the boolean options[:base64_encoded]
  def run_instance(auth = {},args = {})
    amazon = connect(auth)
    
    options = {:min_count => 1, :max_count => 1, :base64_encoded => false, :group_ids => []}
    options.merge!(args)
    
    #verify keypair_name and ami_id passed
    raise Exception, "Keypair name required" if options[:keypair_name].nil?
    raise Exception, "AMI id required" if options[:ami_id].nil?
    
    instance = amazon.run_instances(options[:ami_id], {:minCount=> options[:min_count], :maxCount => options[:max_count], :keyname => options[:keypair_name], :groupIds => options[:group_ids], :userData => options[:user_data], :base64Encoded => options[:base64_encoded]}).parse[1]
    raise Exception, "Instance did not start" unless instance[4] == "pending"
    instance_id = instance[1]
    puts "Instance #{instance_id} Startup Pending"
    
    #loop checking for instance startup
    puts "Checking every 10 seconds to detect startup for up to 5 minutes"
    tries = 0
    begin
      instance_desc = amazon.describe_instances.parse.select { |i| i[1] == instance_id.to_s }[0]
      raise "Server Not Running" unless instance_desc[4] == "running"
      sleep 5
      return instance_desc
    rescue
      puts "."
      sleep 10
      tries += 1
      retry unless tries == 35
      raise "Server Not Running"
    end
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
  
  
  # TODO : GET THIS METHOD WORKING WITH NEW AMAZON-EC2
  #EC2 firewall control
  #
  #Opens access on options[:from_port]-options[:to_port] for the specified security group, ip_protocol, and ip
  def authorize_access(auth = {}, args = {})
    amazon = connect(auth)
    
    options = {:group_name => 'default', :ip_protocol => 'tcp', :cidr_ip => "0.0.0.0/0"}
    options.merge!(args)
    
    #verify from_ip
    raise Exception, "from_port required" if options[:from_port].nil?
    options[:to_port] = options[:from_port] if options[:to_port].nil?
    
    web_security_response = amazon.authorize_security_group_ingress("", :groupName => options[:group_name], :ipProtocol => options[:ip_protocol], :fromPort => options[:from_port], :toPort => options[:to_port], :cidrIp => options[:cidr_ip]).parse.to_s
    raise "Failed Authorizing Web Access" unless web_security_response == "Ingress authorized."
    puts "Access Granted for #{options[:group_name]} group on interface #{options[:cidr_ip]} for #{options[:ip_protocol]} port(s) #{options[:from_port]} to #{options[:to_port]}."
  end
  
  
  # CAPSIZE HELPER METHODS
  #########################################
  # call these from tasks with 'capsize.method_name'
  
  
  # returns an EC2::AWSAuthConnection object
  # requires an auth hash that looks like:
  # {:access_key_id => "my_access_key_id", :secret_access_key => "my_secret_access_key"}
  def connect(args = {})
    
    @secure_config = load_secure_config()
    @capsize_config = load_config()
    
    args = {:access_key_id => @secure_config.aws_access_key_id, :secret_access_key => @secure_config.aws_secret_access_key}.merge(args)
    begin
      amazon = EC2::AWSAuthConnection.new(:access_key_id => args[:access_key_id], :secret_access_key => args[:secret_access_key])
    rescue EC2::Exception => e
      puts "Your EC2 authentication setup failed with the following message : " + e
      raise e
    end
  end
  
  
  def get_instance_id
    
    # Check for the instance_id in the following places in the following order:
    #
    # - In deploy.rb : set :instance_id, "i-FOOBAR"
    # - As an arg on the command line : cap ec2:terminate_instance INSTANCE_ID='i-nnnnnnnn'.
    #   Using this will override anything explicitly set in deploy.rb
    # - If neither of those is set then prompt the user to enter the instance_id 
    #   they want to operate on.
    
    # set :instance_id to the arg passed in on the command line.
    # this will override any existing instance_id that might
    # have been set in deploy.rb (or just set it as a new var)
    unless ENV['INSTANCE_ID'].nil?
      set(:instance_id) do
        ENV['INSTANCE_ID']
      end
    end
    
    # neither deploy.rb or command args were passed to define instance_id.
    # now we prompt the user...
    unless exists?(:instance_id)
      set(:instance_id) do
        Capistrano::CLI.ui.ask "Please specify an instance ID (i-nnnnnnnn) : "
      end
    end
    
    return true
    
  end
  
  
  # load a secure.yaml config file into a OpenStruct object. 
  # This file should not be checked into source control as it
  # contains security sensitive config info (AWS keys).
  def load_secure_config(args = {})
    args = {:config_file => "config/secure.yml"}.merge(args)
    if File.exist?(args[:config_file])
      config = OpenStruct.new(YAML.load_file(args[:config_file]))
      @secure_config = OpenStruct.new(config.send(deploy_env))
    end
  end
  
  
  # load a yaml config file into a OpenStruct object.
  # TODO : When we make changes to this object we'll 
  # save it out to the yaml file again so the changes are persisted.
  def load_config(args = {})
    args = {:config_file => "config/capsize.yml"}.merge(args)
    if File.exist?(args[:config_file])
      config = OpenStruct.new(YAML.load_file(args[:config_file]))
      @capsize_config = OpenStruct.new(config.send(deploy_env))
    end
  end
  
  
  #def save_config(args = {})
  #  args = {:config_file => "config/capsize.yml"}.merge(args)
  #  config_file = args[:config_file]
  #  if File.exist?(config_file)
  #    config = OpenStruct.new(YAML.load_file(config_file))
  #    @capsize_config = OpenStruct.new(config.send(deploy_env))
  #  end
  #end
  
  
end
Capistrano.plugin :capsize, CapsizePlugin