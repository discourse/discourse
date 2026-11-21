# frozen_string_literal: true

module Migrations
  module Importer
    module CLI
      class CustomizationsCommand < Migrations::CLI::Command
        self.description = "Transfer site customizations between a migrated site and the template"

        nested :command,
               {
                 "diff" => CustomizationsCommands::DiffCommand,
                 "plan" => CustomizationsCommands::PlanCommand,
                 "export" => CustomizationsCommands::ExportCommand,
                 "apply" => CustomizationsCommands::ApplyCommand,
               }

        def call
          if @command
            @command.call
          else
            print_usage
          end
        end
      end
    end
  end
end
