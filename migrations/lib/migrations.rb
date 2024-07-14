# frozen_string_literal: true

require "bundler/setup"
Bundler.setup

require "active_support"
require "active_support/core_ext"
require "zeitwerk"

module Migrations
  def self.root_path
    @root_path ||= File.expand_path("..", __dir__)
  end

  def self.load_rails_environment(quiet: false)
    message = "Loading Rails environment ..."
    print message unless quiet

    rails_root = File.expand_path("../..", __dir__)
    # rubocop:disable Discourse/NoChdir
    Dir.chdir(rails_root) do
      begin
        require File.join(rails_root, "config/environment")
      rescue LoadError => e
        $stderr.puts e.message
        raise
      end
    end
    # rubocop:enable Discourse/NoChdir

    print "\r"
    print " " * message.length
    print "\r"
  end

  def self.configure_zeitwerk
    Zeitwerk::Loader.default_logger = method(:puts) if ENV["DEBUG"]

    loader = Zeitwerk::Loader.new

    loader.inflector.inflect({ "cli" => "CLI" })

    loader.push_dir(File.join(Migrations.root_path, "lib"), namespace: Migrations)
    loader.ignore(File.join(Migrations.root_path, "lib", "migrations.rb"))

    loader.setup
  end
end
