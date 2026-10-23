# frozen_string_literal: true

require "json"

module Migrations
  module Importer
    module CLI
      module CustomizationsCommands
        class PlanCommand < Migrations::CLI::Command
          requires_rails!

          self.description =
            "Build an editable plan from a database diff (run against the site the changes live on)"

          options do
            option "-h/--help", "Print out help."
            option "--diff <path>", "JSON report written by `customizations diff --json`."
            option "--output <path>", "Where to write the plan.", default: "customizations.yml"
            option "--mappings-db <path>",
                   "MappingsDB of the import, to recognize imported records."
          end

          def call
            return print_usage if @options[:help]

            diff_path = @options[:diff]
            raise Customizations::Error, "--diff is required" if diff_path.blank?
            unless File.exist?(diff_path)
              raise Customizations::Error, "Diff not found: #{diff_path}"
            end

            matcher = Customizations::Matcher.build(mappings_db_path: @options[:mappings_db])
            begin
              diff = JSON.parse(File.read(diff_path))
              facts = Customizations::Plan::SiteFacts.new(matcher)
              plan, trailer = Customizations::Plan::Builder.new(diff, facts).build
            ensure
              matcher.close
            end

            File.write(@options[:output], Customizations::Plan.dump(plan, trailer:))
            counts = Customizations::Plan::SECTIONS.map { |s| "#{s}: #{plan[s].size}" }
            puts "Plan written to #{@options[:output]} (#{counts.join(", ")})"
            puts "Review it, then run `#{Migrations::CLI::BIN} customizations export`."
          end
        end
      end
    end
  end
end
