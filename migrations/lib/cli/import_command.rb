# frozen_string_literal: true

module Migrations::CLI::ImportCommand
  def self.included(thor)
    thor.class_eval do
      desc "import", "Import a file"
      def import
        require "extralite"

        puts "Importing into Discourse #{Discourse::VERSION::STRING}"
        puts "Extralite SQLite version: #{Extralite.sqlite3_version}"
      end
    end
  end
end
