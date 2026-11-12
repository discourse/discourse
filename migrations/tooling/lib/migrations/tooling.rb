# frozen_string_literal: true

require "zeitwerk"

module Migrations
  module Tooling
    def self.root_path
      @root_path ||= File.expand_path("../..", __dir__)
    end

    def self.loader
      @loader ||=
        begin
          loader = Zeitwerk::Loader.new
          loader.log! if ENV["DEBUG"]
          loader.inflector.inflect("dsl" => "DSL", "cli" => "CLI")
          tooling_dir = File.join(__dir__, "tooling")
          loader.push_dir(tooling_dir, namespace: Tooling)
          loader.ignore(File.join(tooling_dir, "register.rb"))
          loader
        end
    end

    def self.setup_loader
      loader.setup
    end
  end
end

Migrations.register_locale_path(File.join(Migrations::Tooling.root_path, "config", "locales"))
Migrations::Tooling.setup_loader
