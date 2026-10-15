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
            option "--from-backups",
                   "Read the bundle from the site's backup store (S3 or local) instead of a local path."
          end

          one :bundle_path,
              "The ZIP bundle written by `customizations export`, or its file name in the backup store with --from-backups."

          def call
            return print_usage if @options[:help]
            require_positional!(bundle_path, "bundle_path")

            target = @options[:target].to_s
            if Customizations::Plan::APPLY_TARGETS.exclude?(target)
              raise Customizations::Error,
                    "--target must be one of #{Customizations::Plan::APPLY_TARGETS.join(", ")}"
            end

            report =
              if @options[:from_backups]
                Customizations::BackupStoreBundle.open(bundle_path) { |path| apply(path, target) }
              else
                apply(bundle_path, target)
              end

            exit 1 if report.failed?
          end

          private

          def apply(path, target)
            matcher = Customizations::Matcher.build(mappings_db_path: @options[:mappings_db])
            Customizations::Applier.new(
              bundle_path: path,
              target:,
              matcher:,
              dry_run: @options[:dry_run],
            ).run
          ensure
            matcher&.close
          end
        end
      end
    end
  end
end
