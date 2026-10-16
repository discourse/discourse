# frozen_string_literal: true

module Migrations
  module Importer
    module CLI
      class CacheCommand < Migrations::CLI::Command
        class Export < Migrations::CLI::Command
          requires_rails!
          self.description = "Export cooked posts and translations from imported content"
          options { option "-h/--help", "Print out help." }
          one :cache_path, "SQLite cache output path"

          def call
            return print_usage if @options[:help]
            require_positional!(@cache_path, "cache_path")
            puts ContentCache.new.export(@cache_path).inspect
          end
        end

        class Restore < Migrations::CLI::Command
          requires_rails!
          self.description = "Restore matching cooked posts and translations"
          options { option "-h/--help", "Print out help." }
          one :cache_path, "SQLite cache input path"

          def call
            return print_usage if @options[:help]
            require_positional!(@cache_path, "cache_path")
            puts ContentCache.new.restore(@cache_path).inspect
          end
        end

        self.description = "Preserve rendered content across imports"
        nested :command, { "export" => Export, "restore" => Restore }

        def call
          @command ? @command.call : print_usage
        end
      end
    end
  end
end
