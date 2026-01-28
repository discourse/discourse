# frozen_string_literal: true

require "samovar"

module Migrations
  module Core
    module CLI
      class Application < Samovar::Command
        self.description = "Discourse migrations tooling"

        options do
          option "-v/--version", "Print version"
          option "-h/--help", "Show help"
        end

        @commands = {}

        class << self
          attr_reader :commands

          def register(name, command_class)
            @commands[name.to_s] = command_class
          end
        end

        nested :command, ->(key) { Application.commands[key] }, default: nil

        def call
          if @options[:version]
            puts Migrations::Core::VERSION
          elsif @command
            @command.call
          else
            print_usage
          end
        end

        private

        def print_usage
          puts "Usage: disco <command> [options]"
          puts
          puts "Commands:"
          self.class.commands.each do |name, klass|
            puts "  #{name.ljust(12)} #{klass.description}"
          end
        end
      end
    end
  end
end
