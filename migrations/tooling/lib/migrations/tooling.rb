# frozen_string_literal: true

require "zeitwerk"
require "migrations/core"

module Migrations
  module Tooling
    class << self
      def loader
        @loader ||=
          Zeitwerk::Loader.new.tap do |loader|
            tooling_dir = File.expand_path("tooling", __dir__)
            loader.tag = "migrations-tooling"
            loader.inflector.inflect("cli" => "CLI")
            loader.push_dir(tooling_dir, namespace: Migrations::Tooling)
            loader.setup
          end
      end

      def root
        @root ||= File.expand_path("../..", __dir__)
      end
    end

    loader
  end
end

# Register commands with the core CLI
require "migrations/tooling/cli/commands/schema"
require "migrations/tooling/cli/commands/generate"

Migrations::Core::CLI::Application.register(
  "schema",
  Migrations::Tooling::CLI::Commands::Schema
)
Migrations::Core::CLI::Application.register(
  "generate",
  Migrations::Tooling::CLI::Commands::Generate
)
