Gem::Specification.new do |s|
  s.name = %q{capsize}
  s.version = "0.5.0"

  s.specification_version = 2 if s.respond_to? :specification_version=

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ['Jesse Newland','Glenn Rempe']
  s.date = %q{2008-06-10}
  s.description = %q{Capsize is a Capistrano plugin used to provide an easy way to manage and script interaction with the Amazon EC2 service using the amazon-ec2 Ruby gem.}
  s.email = %q{jnewland@gmail.com}
  s.extra_rdoc_files = ["README.textile"]
  s.files = ["History.txt", "License.txt", "Manifest.txt", "README.textile", "Rakefile", "config/hoe.rb", "config/requirements.rb", "examples/capsize.yml.template", "examples/deploy.rb", "lib/capsize.rb", "lib/capsize/capsize.rb", "lib/capsize/configuration.rb", "lib/capsize/ec2.rb", "lib/capsize/ec2_plugin.rb", "lib/capsize/meta_tasks.rb", "lib/capsize/sqs.rb", "lib/capsize/sqs_plugin.rb", "lib/capsize/version.rb", "setup.rb", "tasks/deployment.rake", "tasks/environment.rake", "tasks/website.rake", "test/test_capsize.rb", "test/test_helper.rb"]
  s.has_rdoc = false
  s.homepage = %q{http://github.com/jnewland/capsize}
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{capsize}
  s.rubygems_version = %q{0.5.0}
  s.summary = %q{Capsize is a Capistrano plugin used to provide an easy way to manage and script interaction with the Amazon EC2 service using the amazon-ec2 Ruby gem.}


  s.add_dependency(%q<capistrano>, [">= 2.3.0"])
  s.add_dependency(%q<amazon-ec2>, [">= 0.2.6"])
  s.add_dependency(%q<rcov>, [">= 0.8.1.2.0"])
  s.add_dependency(%q<SQS>, [">= 0.1.5"])
  s.add_dependency(%q<builder>, [">= 2.1.2"])
  s.add_dependency(%q<RedCloth>, [">= 3.0.4"])
end