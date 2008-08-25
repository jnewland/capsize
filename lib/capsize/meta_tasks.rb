Capistrano::Configuration.instance.load do

  namespace :ec2 do

    namespace :setup do

      desc <<-DESC
      Initialize Capsize config.
      You can run this command as often as you like.
      It will not overwrite config files on multiple runs.
      - Create :capsize_config_dir
      - Create :capsize_secure_config_dir
      - Copy capsize.yml.template to :capsize_config_dir/capsize.yml unless it already exists
      - Automatically generate :capsize_secure_config_dir/secure.yml unless it already exists
      - Automatically test authentication configuration with "cap ec2:setup:check"
      - Automatically create a new keypair named by :key_name, or default to :application
      - Automatically create a new security group named by :group_name, or default to :application
      - Add ingress rules for this security group permitting global access on ports 22, 80 and 443
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

        # copy the standard config file template, unless the dest file already exists
        unless File.exists?("#{fetch(:capsize_secure_config_dir)}/#{fetch(:capsize_secure_config_file_name)}")
          puts "Please enter your EC2 account information."
          puts "We'll then write it to a config file at #{fetch(:capsize_secure_config_dir)}/#{fetch(:capsize_secure_config_file_name)}"

          require "yaml"
          set :aws_access_key_id, proc { Capistrano::CLI.ui.ask("AWS Access Key ID : ") }
          set :aws_secret_access_key, proc { Capistrano::CLI.ui.ask("AWS Secret Access Key : ") }

          yaml = {}

          # Populate production element
          yaml['common'] = {}
          yaml['common']['aws_access_key_id'] = aws_access_key_id
          yaml['common']['aws_secret_access_key'] = aws_secret_access_key

          yaml = YAML::dump(yaml).split("\n").collect { |line| line == "common: " ? line += "&common" : line }.join("\n")

          env_config =<<EOF


development:
  <<: *common

  # Uncomment and I only apply to the dev environment
  # or overwrite a common value
  #foo: 'bar'

test:
  <<: *common

staging:
  <<: *common

production:
  <<: *common

  # Uncomment and I only apply to the production environment
  # or overwrite a common value
  #foo: 'baz'
EOF

          yaml += env_config

          File.open("#{fetch(:capsize_secure_config_dir)}/#{fetch(:capsize_secure_config_file_name)}", 'w') do |file|
            file.write(yaml)
          end
          File.chmod 0664, "#{fetch(:capsize_secure_config_dir)}/#{fetch(:capsize_secure_config_file_name)}"
        else
          puts "Warning : The following file was not copied over since it already exists: " + "#{fetch(:capsize_secure_config_dir)}/#{fetch(:capsize_secure_config_file_name)}"
        end

        unless File.exists?("#{fetch(:capsize_config_dir)}/#{fetch(:capsize_config_file_name)}")
          FileUtils.cp("#{fetch(:capsize_examples_dir)}/capsize.yml.template", "#{fetch(:capsize_config_dir)}/#{fetch(:capsize_config_file_name)}", :verbose => true)
        else
          puts "Warning : The following file was not copied over since it already exists: " + "#{fetch(:capsize_config_dir)}/#{fetch(:capsize_config_file_name)}"
        end

        check

        ec2.keypairs.create

        ec2.security_groups.create_with_standard_ports

        message = <<-MESSAGE

        Next up: Pick an Amazon Machine Image and Run it!

          Now you need to select an Amazon EC2 image ID that you want to start as a new
          instance.  The easiest way to do that is to get a list of available images from EC2.

            # Show ALL registered images
            cap ec2:images:show

            # Show MY registered images
            cap ec2:images:show OWNER_ID='self'

            # Show the AMAZON registered images
            cap ec2:images:show OWNER_ID='amazon'

          Select an 'imageId' from the results, and run it:

            cap ec2:instances:run IMAGE_ID='ami-2bb65342'

          You should see some progress information scroll by and finally you should see
          a description of the key attributes of your running intance (dnsName and instanceId
          are likely most important).

          Now lets connect to it with SSH (this may take a few tries, sometimes it takes a
          few minutes for the new instance to respond to SSH):

            cap ec2:instances:ssh INSTANCE_ID='i-xxxxxx'

          If you want to terminate your instance...

            cap ec2:instances:terminate INSTANCE_ID='i-xxxxxx'

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

    end # end namespace :setup

  end # end namespace :ec2

end
