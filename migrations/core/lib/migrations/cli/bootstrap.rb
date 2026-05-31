# frozen_string_literal: true

require "samovar"

module Migrations
  module CLI
    # Builds the Samovar command tree from the registry, selects the command for
    # the given argv, lazily boots Rails when the selected command requires it,
    # and dispatches.
    module Bootstrap
      def self.run(argv)
        top = build_top_command_class.new(argv)

        leaf = deepest_command(top)
        if leaf.class.respond_to?(:requires_rails?) && leaf.class.requires_rails?
          Migrations.load_rails_environment(quiet: true)
        end

        top.call
      rescue Samovar::Error => e
        e.command.print_usage
        exit(1)
      end

      # Walks the nested `command` chain to the deepest selected sub-command.
      def self.deepest_command(command)
        node = command
        node = node.command while node.respond_to?(:command) && node.command
        node
      end

      def self.build_top_command_class
        commands = Registry.command_classes

        Class.new(Migrations::CLI::Command) do
          self.description = "Discourse migration tools"
          nested :command, commands

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
end
