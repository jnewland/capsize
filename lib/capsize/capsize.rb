module Capsize

  # capsize.get(:symbol_name) checks for variables in several places, with this precedence (from low to high):
  # * default capistrano or capsize set variables (available with fetch())
  # * Set in :capsize_config_dir/:capsize_config_file_name (overwrites previous)
  # * Set in :capsize_config_dir/:capsize_secure_config_file_name (overwrites previous)
  # * Passed in as part of the command line params and available as ENV["SYMBOL_NAME"] (overwrites previous)
  #
  def get(symbol=nil)

    raise Exception if symbol.nil? || symbol.class != Symbol # TODO : Jesse: fixup exceptions in capsize

    # populate the OpenStructs with contents of config files so we can query them.
    @capsize_config ||= load_config(:config_file => "#{fetch(:capsize_config_dir)}/#{fetch(:capsize_config_file_name)}")
    @secure_config ||= load_config(:config_file => "#{fetch(:capsize_secure_config_dir)}/#{fetch(:capsize_secure_config_file_name)}")

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

    # Some config values should fall back to reasonable defaults.
    # If we didn't find a value set in any config anywhere, then we should
    # set a reasonable default value for these special cases.  It is better to
    # do this in this one place instead of specifying fallbacks all over the place
    # in the app.  Helps keep it DRY.
    case symbol
    when :group_name
      # the :group_name should fall back to the application name if not provided.
      if fetch(:group_name, nil).nil?
        set symbol, fetch(:application)
      end
    when :key_name
      # the :key_name should fall back to the application name if not provided.
      if fetch(:key_name, nil).nil?
        set symbol, fetch(:application)
      end
    when :group_description
      # the :group_description should fall back to the application name if not provided.
      if fetch(:group_description, nil).nil?
        set symbol, "Security group for the #{fetch(:application)} application."
      end
    end


    # If we have a good set variable then return that variable, else send back a nil
    # if that's what we get and let the calling method either raise an exception
    # or determine how to gracefully handle it.  We don't want to raise an exception every
    # time a get fails.  nil might be just fine as an answer for some questions.
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
end

Capistrano.plugin :capsize, Capsize