# frozen_string_literal: true

module Migrations
  module Importer
    module CLI
      module CustomizationsCommands
        class ApplyCommand < Migrations::CLI::Command
          requires_rails!

          self.description = "Apply a bundle's items for one target to the connected site"

          options do
            option "-h/--help", "Print out help."
            option "--target <target>", "Which items to apply: template or import."
            option "--mappings-db <path>", "MappingsDB of the import, to find imported records."
            option "--dry-run", "Report what would change without changing anything."
          end

          one :bundle_path, "The ZIP bundle written by `customizations export`."

          def call
            return print_usage if @options[:help]
            require_positional!(bundle_path, "bundle_path")

            target = @options[:target].to_s
            if Customizations::Plan::APPLY_TARGETS.exclude?(target)
              raise Customizations::Error,
                    "--target must be one of #{Customizations::Plan::APPLY_TARGETS.join(", ")}"
            end

            matcher = Customizations::Matcher.build(mappings_db_path: @options[:mappings_db])
            report =
              begin
                Customizations::Applier.new(
                  bundle_path:,
                  target:,
                  matcher:,
                  dry_run: @options[:dry_run],
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
