# frozen_string_literal: true

module Migrations
  module Importer
    module CLI
      module CustomizationsCommands
        class ExportCommand < Migrations::CLI::Command
          requires_rails!

          self.description = "Export the current values of all planned items into a ZIP bundle"

          options do
            option "-h/--help", "Print out help."
            option "--plan <path>", "Plan file (see `customizations plan`)."
            option "--output <path>", "Bundle to write.", default: "customizations.zip"
            option "--mappings-db <path>",
                   "MappingsDB of the import, to record ids of imported records."
            option "--upload-base-url <url>",
                   "Download upload files from this site when the store doesn't have them."
            option "--include-secrets", "Write secret setting values into the bundle."
          end

          def call
            return print_usage if @options[:help]
            raise Customizations::Error, "--plan is required" if @options[:plan].blank?

            plan = Customizations::Plan.load(@options[:plan])
            matcher = Customizations::Matcher.build(mappings_db_path: @options[:mappings_db])

            report =
              begin
                Customizations::Exporter.new(
                  plan:,
                  output_path: @options[:output],
                  matcher:,
                  upload_base_url: @options[:upload_base_url],
                  include_secrets: @options[:include_secrets],
                ).run
              ensure
                matcher.close
              end

            exit 1 if report.failed?
          end
        end
      end
    end
  end
end
