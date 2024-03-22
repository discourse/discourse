# frozen_string_literal: true

require "bundler/inline"
require "bundler/ui"

# Redefine gemfile to handle exceptions and print colored error messages
alias original_gemfile gemfile
private :original_gemfile

def gemfile(&gemfile)
  # Create new UI and set level to confirm to avoid printing unnecessary messages
  bundler_ui = Bundler::UI::Shell.new
  bundler_ui.level = "confirm"

  begin
    original_gemfile(true, ui: bundler_ui, &gemfile) # quiet: false,
  rescue Bundler::BundlerError => e
    STDERR.puts "\e[31m#{e.message}\e[0m"
    exit 1
  end
end

def configure_zeitwerk(*directories)
  require "zeitwerk"

  root_path = File.expand_path("..", __dir__)

  loader = Zeitwerk::Loader.new
  directories.each do |dir|
    loader.push_dir(File.expand_path(dir, root_path), namespace: Migrations)
  end
  loader.setup
end
