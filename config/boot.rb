if ENV['DISCOURSE_DUMP_HEAP'] == "1"
  require 'objspace'
  begin
    ObjectSpace.trace_object_allocations_start
  rescue NoMethodError
    puts "Heap dumps not available for Ruby #{RUBY_VERSION} (> 2.1 required)"
  end
end

require 'rubygems'

# Set up gems listed in the Gemfile.
ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../../Gemfile', __FILE__)

require 'bundler/setup' if File.exists?(ENV['BUNDLE_GEMFILE'])
