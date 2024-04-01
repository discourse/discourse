#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../lib/migrations"

module Migrations
  load_rails_environment
  load_gemfiles("common")

  class SchemaGenerator2
    Table = Data.define(:name, :columns, :indexes, :primary_key_column_names)
    Column = Data.define(:name, :datatype, :nullable, :primary_key)

    def initialize(opts = {})
      config = load_config

      @core_db_connection = ActiveRecord::Base.connection

      @table_configs = config[:tables]
      @column_configs = config[:columns]
    end

    def run
      output_tables
    end

    private

    def load_config
      path = File.expand_path("../config/intermediate_db.yml", __dir__)
      YAML.load_file(path, symbolize_names: true)
    end

    def output_tables
      puts "Generating tables..."

      table_names = @table_configs&.keys&.sort || []

      table_names.each do |name|
        raise "Core table named '#{name}' not found" unless valid_table?(name)

        table = generate_table(name)
        output_table(table)
      end
    end

    def generate_table(name)
      pk_columns = @core_db_connection.primary_keys(name)

      columns =
        @core_db_connection
          .columns(name)
          .map { |c| Column.new(c.name, convert_datatype(c), c.null, pk_columns.include?(c.name)) }

      Table.new(name, columns, nil, pk_columns)
    end

    def convert_datatype(column)
      case column.type
      when :string, :inet
        "TEXT"
      else
        column.type.to_s.upcase
      end
    end

    def output_table(table)
      puts "CREATE TABLE #{table.name}"
      puts "("
      output_columns(table)
      puts ");"
    end

    def output_columns(table)
      columns = table.columns
      max_column_name_length = columns.map { |c| c.name.length }.max
      max_datatype_length = columns.map { |c| c.datatype.length }.max
      is_composite_primary_key = table.primary_key_column_names.size > 1

      column_definitions =
        columns
          .sort_by { |c| [c.primary_key ? 0 : 1, c.name] }
          .map do |c|
            definition = [
              c.name.ljust(max_column_name_length),
              c.datatype.ljust(max_datatype_length),
            ]

            definition << "NOT NULL" unless c.nullable
            definition << "PRIMARY KEY" if c.primary_key && !is_composite_primary_key

            definition = definition.join(" ")
            definition.strip!

            "    #{definition}"
          end

      if is_composite_primary_key
        pk_definition = table.primary_key_column_names.join(", ")
        column_definitions << "    PRIMARY KEY (#{pk_definition})"
      end

      puts column_definitions.join(",\n")
    end
  end
end

Migrations::SchemaGenerator2.new.run
