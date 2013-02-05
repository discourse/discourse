require 'rubygems'
require 'bundler'
require 'bundler/gem_tasks'
require 'bundler/setup'

Bundler.require(:default, :test)

task :default => [:spec]

require 'rspec/core'
require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |spec|
    spec.pattern = FileList['spec/**/*_spec.rb']
end
