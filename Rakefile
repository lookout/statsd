require 'bundler'
require 'rspec/core/rake_task'

Bundler::GemHelper.install_tasks

task :default => [:test]

RSpec::Core::RakeTask.new(:test) do |t|
  t.rspec_opts = '-f d --color'
end
