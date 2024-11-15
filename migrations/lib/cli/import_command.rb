# frozen_string_literal: true

require "extralite"

module Migrations::CLI
  class ImportCommand
    def initialize(options)
      @options = options
    end

    def execute
      ::Migrations.load_rails_environment

      puts "Importing into Discourse #{Discourse::VERSION::STRING}"
      puts "Extralite SQLite version: #{Extralite.sqlite3_version}"
    end
  end
end
