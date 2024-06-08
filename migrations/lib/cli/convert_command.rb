# frozen_string_literal: true

module Migrations::CLI::ConvertCommand
  def self.included(thor)
    thor.class_eval do
      desc "convert", "Convert a file"
      def convert
        Migrations.load_rails_environment

        puts "Converting..."

        ::Migrations::IntermediateDB::Migrator.reset!("/tmp/converter/intermediate.db")
        ::Migrations::IntermediateDB::Migrator.migrate("/tmp/converter/intermediate.db")
      end
    end
  end
end
