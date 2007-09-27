
%w[ test/unit rubygems test/spec mocha stubba ].each { |f| 
  begin
    require f
  rescue LoadError => e
    abort "Unable to load required gem for running tests: #{f}" + e
  end
}

require File.dirname(__FILE__) + '/../lib/capsize'
