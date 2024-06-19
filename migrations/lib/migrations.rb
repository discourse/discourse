# frozen_string_literal: true

require "bundler/setup"
Bundler.setup

require "active_support"
require "active_support/core_ext"
require "zeitwerk"

module Migrations
  class NoSettingsFound < StandardError
  end

  def self.root_path
    @root_path ||= File.expand_path("..", __dir__)
  end

  def self.load_rails_environment(quiet: false)
    message = "Loading Rails environment ..."
    print message unless quiet

    rails_root = File.expand_path("../..", __dir__)
    # rubocop:disable Discourse/NoChdir
    Dir.chdir(rails_root) { require File.join(rails_root, "config/environment") }
    # rubocop:enable Discourse/NoChdir

    print "\r"
    print " " * message.length
    print "\r"
  end

  def self.configure_zeitwerk
    Zeitwerk::Loader.default_logger = method(:puts) if ENV["DEBUG"]

    loader = Zeitwerk::Loader.new

    loader.inflector.inflect({ "cli" => "CLI", "intermediate_db" => "IntermediateDB" })

    loader.push_dir(File.join(Migrations.root_path, "lib"), namespace: Migrations)
    loader.ignore(File.join(Migrations.root_path, "lib", "migrations.rb"))

    loader.setup
  end
end
