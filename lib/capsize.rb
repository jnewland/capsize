# Require all necessary libraries
%w[
  rubygems
  ostruct
  yaml
  fileutils
  builder
  capistrano
  EC2
  sqs
  capsize/version
  capsize/capsize.rb
  capsize/meta_tasks
  capsize/ec2
  capsize/ec2_plugin
  capsize/sqs
  capsize/sqs_plugin
  capsize/configuration
].each { |lib|
  begin
    require lib
  rescue Exception => e
    puts "The loading of '#{lib}' failed in capsize.rb with message : " + e
    exit
  end
}
