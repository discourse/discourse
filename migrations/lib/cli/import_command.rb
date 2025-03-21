# frozen_string_literal: true

require "extralite"

module Migrations::CLI
  class ImportCommand
    def initialize(options)
      @options = options
    end

    def execute
      ::Migrations.load_rails_environment(quiet: true)

      ::Migrations::Importer.execute
    end
  end
end
