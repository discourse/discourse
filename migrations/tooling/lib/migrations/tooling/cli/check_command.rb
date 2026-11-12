# frozen_string_literal: true

require "colored2"

module Migrations
  module Tooling
    module CLI
      # `disco check` — the single entrypoint for all source-tree checks.
      # Without a subcommand it runs every check in dependency order and
      # stops at the first failing link, since everything downstream of a
      # stale link would report against stale inputs.
      class CheckCommand < Migrations::CLI::Command
        self.description = "Run all schema and converter checks"

        # NOTE: no group-level `-h/--help` option — the option hoisting in
        # `Command#parse` would steal `--help` from the subcommands
        # (`check schema --help` would run the check). A bare `--help`
        # surfaces as an unparsable token, which Bootstrap turns into usage.

        nested :command,
               {
                 "schema" => CheckCommands::SchemaCommand,
                 "coverage" => CheckCommands::CoverageCommand,
               }

        def call
          if @command
            @command.call
          else
            run_all
          end
        end

        private

        def run_all
          # The schema checks need Rails. This command itself doesn't declare
          # `requires_rails!` so that `check coverage` and `--help` stay
          # Rails-free; the all-checks mode boots it here instead.
          Migrations.load_rails_environment(quiet: true)

          puts "Checking schema config and generated files...".bold
          unless CheckCommands::SchemaCommand.new([]).run
            puts
            puts "Skipping the remaining checks, they would run against stale inputs.".red
            exit 1
          end

          puts
          puts "Checking converter coverage...".bold
          exit 1 unless CheckCommands::CoverageCommand.new([]).run
        end
      end
    end
  end
end
