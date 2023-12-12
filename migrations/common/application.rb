# frozen_string_literal: true

require "bundler/inline"
require "bundler/ui"

alias original_gemfile gemfile
private :original_gemfile

def gemfile(&gemfile)
  begin
    original_gemfile(true, quiet: true, &gemfile)
  rescue Bundler::BundlerError => e
    STDERR.puts "\e[31m#{e.message}\e[0m"
    exit 1
  end
end
