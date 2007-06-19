post-commit test checkins

= Capsize

Capsize provides Capistrano tasks to manage Amazon EC2. Capsize depends on the following gems being installed:

  Capistrano 2.0 [ http://www.capify.org ] >= 1.99.0
  Amazon EC2 [ http://amazon-ec2.rubyforge.org/ ] >= 0.2.0

This project is in no way endorsed, sponsored by, or associated with Amazon, Amazon.com, or Amazon Web Services.

== Installation

* <tt>gem install capsize</tt>
* Edit your your <tt>config/deploy.rb</tt>:

    require 'capsize'

    set :application, "set your application name here"
    set :repository,  "set your repository location here"

* Run <tt>cap deploy:setup</tt>
* Paste the generated config into config/deploy.rb 
    
== Tasks

===== Notes:

* <em>All tasks <b>require</b> aws_access_key_id and aws_secret_access_key.</em>
* <em>All tasks optionally take environment variables in lieu of capistrano configuration variables.</em>

[ec2:create_keypair]                Create a keypair aws_keypair_name and write out the generate private key to aws_private_key_path.
[ec2:delete_keypair]                Deletes keypair aws_keypair_name.                                                                
[ec2:describe_keypairs]             Describes keypairs.
[ec2:describe_images]               Describes AMIs you have privilege to execute.
[ec2:run_instance]                  Runs an instance of aws_ami_id with access available via aws_keypair_name.
[ec2:terminate_instance]            Terminates aws_instance_id.
[ec2:describe_instances]            Describes running AMIs.                 
[ec2:authorize_web_and_ssh_access]  Opens tcp access on port 80 and 22 to the aws_security_group.

== Meta

Rubyforge Project Page:: http://rubyforge.org/projects/capsize
Author::    Glenn Rempe (grempe@rubyforge.org[mailto:grempe@rubyforge.org])
Author::    Jesse Newland (http://soylentfoo.jnewland.com) (jnewland@gmail.com[mailto:jnewland@gmail.com])
Copyright:: Copyright (c) 2007 Glenn Rempe, Jesse Newland
License::   Distributes under the same terms as Ruby
