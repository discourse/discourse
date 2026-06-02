# frozen_string_literal: true

module Migrations
  module Tooling
    module CLI
      class SchemaCommand < Migrations::CLI::Command
        self.description = "Manage the IntermediateDB schema"

        nested :command,
               {
                 "generate" => SchemaCommands::GenerateCommand,
                 "validate" => SchemaCommands::ValidateCommand,
                 "list" => SchemaCommands::ListCommand,
                 "diff" => SchemaCommands::DiffCommand,
                 "add" => SchemaCommands::AddCommand,
                 "ignore" => SchemaCommands::IgnoreCommand,
                 "refresh-plugins" => SchemaCommands::RefreshPluginsCommand,
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
