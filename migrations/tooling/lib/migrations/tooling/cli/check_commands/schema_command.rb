# frozen_string_literal: true

require "colored2"

module Migrations
  module Tooling
    module CLI
      module CheckCommands
        # `disco check schema` — validates the schema pipeline up to the
        # generated artifacts, in dependency order:
        #
        #   1. the dev database has no pending migrations (otherwise every
        #      later answer compares against a stale baseline)
        #   2. the schema config is internally valid
        #   3. every database table and column is either configured or ignored
        #      (drift — reported with `schema add`/`ignore`/`generate` suggestions)
        #   4. the committed generated files match what generation produces
        #
        # It stops at the first failing link, since everything downstream
        # would report against stale inputs.
        class SchemaCommand < SchemaCommands::BaseCommand
          include SchemaCommands::DiffOutput

          self.description = "Check schema config against the database and generated files"

          options do
            option "-h/--help", "Print out help."
            option "--db <name>", "Database configuration to use.", default: "intermediate_db"
          end

          def call
            return print_usage if @options[:help]

            exit 1 unless run
          end

          def run
            database = selected_database

            check_pending_migrations && check_config_validity(database) &&
              check_config_drift(database) && check_artifacts(database)
          end

          private

          def check_config_validity(database)
            errors = schema.validate(database:)
            return true if errors.empty?

            puts "✗ The schema config is invalid:".red
            errors.each { |error| puts "  - #{error}" }
            false
          end

          def check_pending_migrations
            return true unless ActiveRecord::Base.connection_pool.migration_context.needs_migration?

            puts "✗ The database has pending migrations, the checks would run against a stale baseline.".red
            puts "  Run `bin/rake db:migrate` first."
            false
          end

          def check_config_drift(database)
            result = schema.diff(database:)
            return true unless result.actionable?

            puts "✗ The schema config is out of sync with the database.".red
            puts
            display_diff(result, database:)
            false
          end

          def check_artifacts(database)
            result = Schema::DSL::ArtifactsChecker.new(schema, database:).check

            if result.clean?
              puts "✓ Schema config matches the database and the generated files.".green
              return true
            end

            puts "✗ The generated files are out of date.".red
            result.changed.each { |path| puts "  ~ #{path} (outdated)".yellow }
            result.missing.each { |path| puts "  + #{path} (not committed)".green }
            result.stale.each { |path| puts "  - #{path} (no longer generated)".red }
            puts
            puts "Run `#{Migrations::CLI::BIN} schema generate` and commit the result."
            false
          end
        end
      end
    end
  end
end
