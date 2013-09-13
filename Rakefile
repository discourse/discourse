#!/usr/bin/env rake
require "rspec/core/rake_task"
require "yard"

begin
  Bundler.setup :default, :development
  Bundler::GemHelper.install_tasks
rescue Bundler::BundlerError => error
  $stderr.puts error.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit error.status_code
end

RSpec::Core::RakeTask.new(:spec)

desc "Generate all of the docs"
YARD::Rake::YardocTask.new do |config|
  config.files = Dir["lib/**/*.rb"]
end

desc "Default: run tests and generate docs"
task :default => [ :spec, :yard ]
