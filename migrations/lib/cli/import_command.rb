# frozen_string_literal: true

module Migrations
  module CLI
    class ImportCommand
      def initialize(options)
        @options = options
      end

      def execute
        Migrations.load_rails_environment(quiet: true)

        Importer.execute(@options)
      end
    end
  end
end
