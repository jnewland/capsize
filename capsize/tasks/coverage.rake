desc 'Runs RCOV and generates test coverage reports which are stored in coverage/ dir'
task :test_coverage do
  sh %{rcov -T test/*.rb}
end
