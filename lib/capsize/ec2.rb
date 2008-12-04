Capistrano::Configuration.instance.load do

  namespace :ec2 do


    # CONSOLE TASKS
    #########################################

    namespace :console do

      desc <<-DESC
      Show instance console output.
      You can view the console of a specific instance by doing one of the following:
      - define an :instance_id in any Capsize config file with "set :instance_id, 'i-123456'"
      - Override this on the command line with "cap ec2:console:output INSTANCE_ID='i-123456'"
      - If neither of these are provided you will be prompted by Capistano for the instance ID you wish to terminate.
      DESC
      task :output do

        capsize.get(:instance_id)

        case instance_id
        when nil, ""
          puts "You don't seem to have set an instance ID..."
        else
          begin
            capsize_ec2.get_console_output(:instance_id => instance_id).each_pair do |key, value|
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
      # FIXME : Bug with shadowing existing method
      desc <<-DESC
      Describes your keypairs.
      This will return a text description of all of your personal keypairs created on EC2.
      Remember that these keypairs are only usable if you have the private key material stored locally
      and you specify this keypair as part of the run instances command.  Only then will you be able to
      take advantage of logging into remote servers using public key authentication.  This command
      will also display whether you have a locally installed private key that matches the key_name of
      the public key being described.
      DESC
      task :show do
        begin
          capsize_ec2.describe_keypairs().keySet.item.each do |item|
            puts "[#{item.keyName}] : keyName = " + item.keyName
            puts "[#{item.keyName}] : keyFingerprint = " + item.keyFingerprint

            key_file = capsize_ec2.get_key_file(:key_name => item.keyName)

            puts "[#{item.keyName}] : OK : matching local private key found @ #{key_file}" if File.exists?(key_file)
            puts "[#{item.keyName}] : WARNING : matching local private key NOT found @ #{key_file}" unless File.exists?(key_file)
            puts ""
          end
        rescue Exception => e
          puts "The attempt to show your keypairs failed with error : " + e
          raise e
        end
      end


      desc <<-DESC
      Create and store a new keypair.
      This command will generate a new keypair for you on EC2 and will also
      save a local copy of your private key in the filepath specified by
      KEY_DIR and KEY_NAME.  By default the keypair will be named the
      same as your Capistrano application's name, and the private key will
      be stored in your capsize config dir.  If a keypair already exists
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
          puts "Generating keypair... (this may take a few seconds)"
          key_name, key_file = capsize_ec2.create_keypair()
          puts "A keypair with the name \"#{key_name}\" has been generated and saved here:\n #{key_file}"
        rescue Exception => e
          puts "The attempt to create a keypair failed with the error : " + e
          raise e
        end
      end


      desc <<-DESC
      Delete a keypair.
      This command will delete a keypair from EC2 and will also
      delete the local copy of your private key in the filepath specified by
      KEY_DIR and KEY_NAME.  By default the keypair deleted will be named the
      same as your Capistrano application's name, and the private key will
      be deleted from your capsize config dir.  You will be prompted to confirm
      deletion of your keypair before the action will proceed.

      WARNING : Don't delete keypairs which may be associated with
      running instances on EC2.  If you do so you may lose the ability
      to access these servers via SSH and Capistrano!  Your last resort in
      this case may be to terminate those running servers.
      DESC
      task :delete do

        key_name = capsize.get(:key_name)

        confirm = (Capistrano::CLI.ui.ask("WARNING! Are you sure you want to delete the local and remote parts of the keypair with the name \"#{key_name}\"?\nYou will no longer be able to access any running instances that depend on this keypair!? (y/N): ").downcase == 'y')

        if confirm
          begin
            capsize_ec2.delete_keypair()
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


      desc <<-DESC
      Open an SSH shell to instance_id.
      This command makes it easy to open an interactive SSH session with one
      of your running instances.  Just set instance_id in one of your config
      files, or pass in INSTANCE_ID='i-123456' to this task and an SSH
      connection to the public DNS name for that instance will be started.
      SSH is configured to use try the public key pair associated with
      your application for authentication assuming you started your instance
      to be associated with that key_name.  The option StrictHostKeyChecking=no
      is passed to your local SSH command to avoid prompting the user regarding
      adding the remote host signature to their SSH known_hosts file as these
      server signatures will typically change often anyway in the EC2 environment.
      Task assumes you have a local 'ssh' command on your shell path, and that you
      are using OpenSSH.  Your mileage may vary with other SSH implementations.
      DESC
      task :ssh do

        capsize.get(:instance_id)

        case instance_id
        when nil, ""
          puts "You don't seem to have set an instance_id in your config or passed an INSTANCE_ID environment variable..."
        else

          begin
            dns_name = capsize_ec2.hostname_from_instance_id(capsize.get(:instance_id))
          rescue Exception => e
            puts "The attempt to get the DNS name for your instance failed with the error : " + e
          end

          key_file = capsize_ec2.get_key_file

          # StrictHostKeyChecking=no ensures that you won't be prompted each time for adding
          # the remote host to your ssh known_hosts file.  This should be ok as the host IP
          # and fingerprint will constantly change as you start and stop EC2 instances.
          # For the ultra paranoid who are concerned about man-in-the-middle attacks you
          # may want to do ssh manually, and perhaps not use no-password public key auth.
          #
          # example connect :  ssh -o StrictHostKeyChecking=no -i config/id_rsa-myappkey root@ec2-72-44-51-000.z-1.compute-1.amazonaws.com
          puts "Trying to connect with host with local shell command:"
          puts "ssh -o StrictHostKeyChecking=no -i #{key_file} root@#{dns_name}"
          puts "--\n"
          system "ssh -o StrictHostKeyChecking=no -i #{key_file} root@#{dns_name}"
        end
      end


      desc <<-DESC
      Start an EC2 instance.
      Runs an instance of :image_id with the keypair :key_name and group :group_name.
      DESC
      task :run do
        begin

          response = capsize_ec2.run_instance

          puts "An instance has been started with the following metadata:"
          capsize_ec2.print_instance_description(response)

          instance_id = response.reservationSet.item[0].instancesSet.item[0].instanceId
          puts "SSH:"
          puts "cap -s instance_id='#{instance_id}' ec2:instances:ssh"
          puts ""

          # TODO : Tell the user exactly what instance info they need to put in their deploy.rb
          # to make the control of their server instances persistent!
          #capsize_ec2.print_config_instructions(:response => response)

          # TODO : I think this (set_default_roles_to_target_role) is only good if we are only
          # dealing with one server.  But the values are temporary.  How should we handle multiple
          # instances starting that need to be controlled?  How should we handle storing this important data
          # more persistently??
          #
          # override the roles set in deploy.rb with the server instance started here.
          # This is temporary and only remains defined for the length of this
          # capistrano run!
          #set(:dns_name, response.reservationSet.item[0].instancesSet.item[0].dnsName)
          #set_default_roles_to_target_role

        rescue Exception => e
          puts "The attempt to run an instance failed with the error : " + e
        end
      end


      desc <<-DESC
      Terminate an EC2 instance.
      You can terminate a specific instance by doing one of the following:
      - define an :instance_id in deploy.rb with "set :instance_id, 'i-123456'"
      - Override this on the command line with "cap ec2:instances:terminate INSTANCE_ID='i-123456'"
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
              response = capsize_ec2.terminate_instance({:instance_id => instance_id})
              puts "The request to terminate instance_id #{instance_id} has been accepted.  Monitor the status of the request with 'cap ec2:instances:show'"
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
      - Override this on the command line with "cap ec2:instances:reboot INSTANCE_ID='i-123456'"
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
              response = capsize_ec2.reboot_instance({:instance_id => instance_id})
              puts "The request to reboot instance_id \"#{instance_id}\" has been accepted.  Monitor the status of the request with 'cap ec2:instances:show'"
            rescue Exception => e
              puts "The attempt to reboot the instance_id \"#{instance_id}\" failed with error : " + e
              raise e
            end
          else
            puts "Your reboot instance request has been cancelled."
          end
        end
      end


      desc <<-DESC
      Show and describe current instances.
      Will show the current metadata and status for all instances that you own.
      DESC
      task :show do

        begin
          result = capsize_ec2.describe_instances()
        rescue Exception => e
          puts "The attempt to show your instances failed with error : " + e
          raise e
        end

        capsize_ec2.print_instance_description(result)
      end

    end


    # SECURITY GROUP TASKS
    #########################################


    namespace :security_groups do

      desc <<-DESC
      Create a security group.
      Create a new security group specifying:
        - :group_name or GROUP_NAME (defaults to application name)
        - :group_description or GROUP_DESCRIPTION (defaults to generic description including application name)
      DESC
      task :create do
        begin
          capsize_ec2.create_security_group()
          puts "The security group \"#{capsize.get(:group_name)}\" has been created."
        rescue EC2::InternalError => e
          # BUG : Bug in EC2.  Is throwing InternalError instead of InvalidGroupDuplicate if you try to create a group that exists.  Catch both.
          # REMOVE THIS RESCUE WHEN BUG IS FIXED BY AWS
          puts "The security group you specified for group name \"#{capsize.get(:group_name)}\" already exists (EC2::InternalError)."
          # Don't re-raise this exception
        rescue EC2::InvalidGroupDuplicate => e
          puts "The security group you specified for group name \"#{capsize.get(:group_name)}\" already exists (EC2::InvalidGroupDuplicate)."
          # Don't re-raise this exception
        rescue Exception => e
          puts "The attempt to create security group \"#{capsize.get(:group_name)}\" failed with the error : " + e
          raise e
        end

      end

      desc <<-DESC
      Show and describes security groups.
      This will return a description of your security groups on EC2.
      Pass in GROUP_NAME to limit to a specific group.
      DESC
      task :show do
        begin
          capsize_ec2.describe_security_groups().securityGroupInfo.item.each do |group|
            puts "[#{group.groupName}] : groupName = " + group.groupName
            puts "[#{group.groupName}] : groupDescription = " + group.groupDescription
            puts "[#{group.groupName}] : ownerId = " + group.ownerId

            unless group.ipPermissions.nil?
              group.ipPermissions.item.each do |permission|
                puts "  --"
                puts "  ipPermissions:ipProtocol = " + permission.ipProtocol unless permission.ipProtocol.nil?
                puts "  ipPermissions:fromPort = " + permission.fromPort unless permission.fromPort.nil?
                puts "  ipPermissions:toPort = " + permission.toPort unless permission.toPort.nil?
                puts "  ipPermissions:sourceSecurityGroupName = " + permission.groups.item.first.groupName unless permission.groups.nil?
                puts "  ipPermissions:sourceSecurityGroupOwnerId = " + permission.groups.item.first.userId unless permission.groups.nil?
                
                unless permission.ipRanges.nil?
                  permission.ipRanges.item.each do |range|
                    puts "  ipRanges:cidrIp = " + range.cidrIp unless range.cidrIp.nil?
                  end
                end

              end
            end

            puts ""
          end
        rescue Exception => e
          puts "The attempt to show your security groups failed with error : " + e
          raise e
        end
      end


      desc <<-DESC
      Delete a security group.
      Delete a security group specifying:
        - :group_name or GROUP_NAME (defaults to application name)
      DESC
      task :delete do
        begin
          capsize_ec2.delete_security_group()
          puts "The security group \"#{capsize.get(:group_name)}\" has been deleted."
        rescue Exception => e
          puts "The attempt to delete security group \"#{capsize.get(:group_name)}\" failed with the error : " + e
          raise e
        end

      end


      desc <<-DESC
      Authorize firewall ingress for the specified GROUP_NAME and FROM_PORT.
      This calls authorize_ingress for the group defined in the :group_name variable
      and the port specified in :from_port and :to_port. Any instances that were started and set to
      use the security group :group_name will be affected as soon as possible. You can
      specify a port range, instead of a single port if both FROM_PORT and TO_PORT are passed in.
      DESC
      task :authorize_ingress do

        begin
          capsize_ec2.authorize_ingress({:group_name => capsize.get(:group_name), :from_port => capsize.get(:from_port), :to_port => capsize.get(:to_port)})
          puts "Firewall ingress granted"
        rescue EC2::InvalidPermissionDuplicate => e
          puts "The firewall ingress rule you specified for group name \"#{capsize.get(:group_name)}\" was already set (EC2::InvalidPermissionDuplicate)."
          # Don't re-raise this exception
        rescue Exception => e
          puts "The attempt to allow firewall ingress for security group \"#{capsize.get(:group_name)}\" failed with the error : " + e
          raise e
        end

      end


      desc <<-DESC
      Create security group and open web ports.
      Will create a new group which is named by default the same as your application.
      Will also authorize firewall ingress for the specified GROUP_NAME on standard web ports:
        - 22 (SSH)
        - 80 (HTTP)
        - 443 (HTTPS)
      By default the group name created is the same as your :application name
      in deploy.rb.  You can override the group name used by setting
      :group_name or by passing in the environment variable GROUP_NAME=''
      on the cap command line.  Any instances that were started and set
      to use the security group GROUP_NAME will be affected as soon as possible.
      DESC
      task :create_with_standard_ports do

        begin
          capsize_ec2.create_security_group()
          puts "The security group \"#{capsize.get(:group_name)}\" has been created."
        rescue EC2::InvalidGroupDuplicate => e
          puts "The security group you specified for group name \"#{capsize.get(:group_name)}\" already exists (EC2::InvalidGroupDuplicate)."
          # Don't re-raise this exception
        rescue Exception => e
          puts "The attempt to create security group \"#{capsize.get(:group_name)}\" failed with the error : " + e
          raise e
        end

        ports = [22, 80, 443]
        ports.each { |port|
          begin
            capsize_ec2.authorize_ingress({:group_name => capsize.get(:group_name), :from_port => "#{port}", :to_port => "#{port}"})
            puts "Firewall ingress granted for #{capsize.get(:group_name)} on port #{port}"
          rescue EC2::InvalidPermissionDuplicate => e
            puts "The firewall ingress rule you specified for group name \"#{capsize.get(:group_name)}\" on port #{port} was already set (EC2::InvalidPermissionDuplicate)."
            # Don't re-raise this exception
          rescue Exception => e
            puts "The attempt to allow firewall ingress on port #{port} for security group \"#{capsize.get(:group_name)}\" failed with the error : " + e
            raise e
          end
        }

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
          capsize_ec2.revoke_ingress({:group_name => capsize.get(:group_name), :from_port => capsize.get(:from_port), :to_port => capsize.get(:to_port)})
          puts "Firewall ingress revoked for #{capsize.get(:group_name)}"
        rescue Exception => e
          puts "The attempt to revoke firewall ingress permissions for security group \"#{capsize.get(:group_name)}\" failed with the error : " + e
          raise e
        end

      end

    end


    # IMAGE TASKS
    #########################################

    namespace :images do

      desc <<-DESC
      Show and describe machine images you can execute.
      Will show all machine images you have permission to execute by default.
      You can limit by passing in:
      OWNER_ID='self', OWNER_ID='amazon', OWNER_ID='__SOME_OWNER_ID__'
      EXECUTABLE_BY='__SOME_OWNER_ID__'
      IMAGE_ID='__SOME_IMAGE_ID__'
      DESC
      task :show do
        begin
          capsize_ec2.describe_images().imagesSet.item.each do |item|
            puts "imageId = " + item.imageId unless item.imageId.nil?
            puts "imageLocation = " + item.imageLocation unless item.imageLocation.nil?
            puts "imageOwnerId = " + item.imageOwnerId unless item.imageOwnerId.nil?
            puts "imageState = " + item.imageState unless item.imageState.nil?
            puts "isPublic = " + item.isPublic unless item.isPublic.nil?
            puts ""
          end
        rescue Exception => e
          puts "The attempt to show images failed with error : " + e
          raise e
        end
      end

    end


    # ELASTIC IP (ADDRESSES) TASKS
    #########################################

    namespace :addresses do

      desc <<-DESC
      Show and describe elastic IP addresses assigned to your account.
      DESC
      task :show do
        begin
          result = capsize_ec2.describe_addresses()
        rescue Exception => e
          puts "The attempt to show elastic IP addresses failed with error : " + e
          raise e
        end
        
        capsize_ec2.print_address_description(result)
      end

      desc <<-DESC
      Acquire a new elastic IP address for use with your account.
      DESC
      task :allocate do
        begin
          print "Allocating elastic IP address ... "
          $stdout.flush
          response = capsize_ec2.allocate_address()
          puts "success"
          puts "Allocated address: #{response.publicIp}"
          puts ""
        rescue Exception => e
          puts "failed"
          puts "The attempt to allocate an elastic IP addresses failed with error : " + e
          raise e
        end
      end

      desc <<-DESC
      Release an elastic IP from your account.
      You can release a specific elastic IP by doing one of the following:
      - define a :public_ip in deploy.rb with "set :public_ip, '123.1.2.3'"
      - Override this on the command line with "cap ec2:addresses:release PUBLIC_IP='123.1.2.3'"
      DESC
      task :release do

        capsize.get(:public_ip)

        case public_ip
        when nil, ""
          puts "You don't seem to have set a public_ip ..."
        else
          confirm = (Capistrano::CLI.ui.ask("WARNING! Really release elastic IP address \"#{public_ip}\"? (y/N): ").downcase == 'y')
          if confirm
            begin
              response = capsize_ec2.release_address({:public_ip => public_ip})
              puts "The request to release elastic IP address #{public_ip} has been accepted.  Monitor the status of the request with 'cap ec2:addresses:show'"
            rescue Exception => e
              puts "The attempt to release the elastic IP address failed with error : " + e
              raise e
            end
          else
            puts "Your address release request has been cancelled."
          end
        end
      end


      desc <<-DESC
      Associate an elastic IP address with an instance.
      If the IP address is currently assigned to another instance, the IP address
      is assigned to the new instance.

      You must supply both a public_ip (this is the elastic IP address you want to assign)
      and an instance_id (this is the instance to which you want to assign the address)

      You can associate an elastic IP with an instance by doing one of the following:
      - Define these variables in deploy.rb with "set :public_ip, '123.1.2.3'; set :instance_id, 'i-12312312';"
      - Override this on the command line with "cap ec2:addresses:associate PUBLIC_IP='123.1.2.3' INSTANCE_ID='i-12312312'"
      - A combination of the above.
      DESC
      task :associate do

        capsize.get(:public_ip)
        capsize.get(:instance_id)

        if !public_ip || public_ip == ''
          puts "You don't seem to have set a public_ip ..."
        elsif !instance_id || instance_id == ''
          puts "You don't seem to have set an instance_id ..."
        else
          #TODO: check if this IP is already assigned to another instance and make 
          # the user confirm the new association if that's the case
          begin
            response = capsize_ec2.associate_address(:public_ip => public_ip, :instance_id => instance_id)
            puts "The elastic IP address #{public_ip} has been associated with " +
                 "instance #{instance_id}."
            puts "** It may take several minutes for this mapping to take effect."
          rescue Exception => e
            puts "The attempt to associate the elastic IP address failed with error : " + e
            raise e
          end
        end
      end


      desc <<-DESC
      Disassociates the specified elastic IP from whatever instance it's 
      currently associated with

      You can disassociate a specific elastic IP by doing one of the following:
      - define a :public_ip in deploy.rb with "set :public_ip, '123.1.2.3'"
      - Override this on the command line with "cap ec2:addresses:disassociate PUBLIC_IP='123.1.2.3'"
      - If neither of these are provided you will be prompted by Capistano for the IP you wish to disassociate.
      DESC
      task :disassociate do

        capsize.get(:public_ip)

        case public_ip
        when nil, ""
          puts "You don't seem to have set a public_ip ..."
        else
          confirm = (Capistrano::CLI.ui.ask("WARNING! Really disassociate elastic IP address \"#{public_ip}\"? (y/N): ").downcase == 'y')
          if confirm
            begin
              response = capsize_ec2.disassociate_address({:public_ip => public_ip})
              puts "The elastic IP address #{public_ip} has been disassociated."
            rescue Exception => e
              puts "The attempt to disassociate the elastic IP address failed with error : " + e
              raise e
            end
          else
            puts "Your address disassociation request has been cancelled."
          end
        end
      end

    end # end namespace :addresses


    # VOLUME TASKS
    #########################################
     
      namespace :volumes do 
        desc <<-DESC
        Describes existing volumes.
        DESC
        task :show do
          begin
            amazon = capsize_ec2.connect
            volumes = amazon.describe_volumes
          
            if volumes.volumeSet && volumes.volumeSet.item
              volumes.volumeSet.item.each do |volume|
                puts "volume:volumeId = #{volume.volumeId}"
                %w(status size snapshotId availabilityZone attachmentSet createTime).each do |field|
                  puts "  volume:#{field} = #{volume[field]}"
                end
              end
            else
              puts "You have no volumes"
            end
          rescue Exception => e
            puts "The attempt to show volumes failed with the error : " + e
            raise e
          end
        end

        desc <<-DESC
        Create a new EBS volume.
        This will create a new EBS volume of SIZE Gb in the availability zone given as ZONE
        (eg us-east-1{a,b,c})
        So to create a 10Gb volume in zone 'us-east-1c':
         cap ec2:volumes:create SIZE=10 ZONE=us-east-1c
        DESC
        task :create do
          begin
            size = capsize.get(:size)
            zone = capsize.get(:zone)

            puts "Creating #{size}Gb volume in #{zone}"

            amazon = capsize_ec2.connect
            res = amazon.create_volume :size => size, :availability_zone => zone
            puts "Created volume #{res["volumeId"]}"

          rescue Exception => e
            puts "The attempt to create a volume failed with the error : " + e
            raise e
          end
        end

        desc <<-DESC
        Attach an EBS volume to an instance.
        This will attach the EBS volume VOLUME_ID to the instance INSTANCE_ID
        at the device path DEVICE.
        DESC
        task :attach do
          begin
            volume_id = capsize.get :volume_id
            instance_id = capsize.get :instance_id
            device = capsize.get :device
            puts "Attaching volume #{volume_id} to instance #{instance_id} at #{device}"

            amazon = capsize_ec2.connect
            response = amazon.attach_volume :volume_id => volume_id, :instance_id => instance_id, :device => device
            if response.res == "true"
              puts "Volume #{volume_id} attached to #{instance_id}"
            end
          rescue Exception => e
            puts "The attempt to attach volume #{volume_id} failed with the error : " + e
            raise e
          end
        end

        desc <<-DESC
        Detach an EBS volume.
        This will detach the EBS volume VOLUME_ID from any instance it is connected to.
        DESC
        task :detach do
          begin
            volume_id = capsize.get :volume_id
            puts "Detaching volume #{volume_id}"

            amazon = capsize_ec2.connect
            response = amazon.detach_volume :volume_id => volume_id
            if response.res == "true"
              puts "Volume #{volume_id} detached"
            end
          rescue Exception => e
            puts "The attempt to detach volume #{volume_id} failed with the error : " + e
            raise e
          end
        end

        desc <<-DESC
        Delete an EBS volume.
        This will delete the EBS volume VOLUME_ID.
        DESC
        task :delete do 

          confirm = (Capistrano::CLI.ui.ask("WARNING! Really terminate instance \"#{instance_id}\"? (y/N): ").downcase == 'y')
          if confirm
            begin
              volume_id = capsize.get :volume_id
              puts "Deleting volume #{volume_id}"
              
              amazon = capsize_ec2.connect
              response = amazon.delete_volume :volume_id => volume_id
              if response.res == "true"
                puts "Volume #{volume_id} deleted"
              end
            rescue Exception => e
              puts "The attempt to create a volume failed with the error : " + e
              raise e
            end
          end
        end

      end # end namespace :volumes


  end # end namespace :ec2
end # end Capistrano::Configuration.instance.load
