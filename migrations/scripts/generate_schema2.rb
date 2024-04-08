#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../lib/migrations"

module Migrations
  load_rails_environment
  load_gemfiles("common")

  Table = Data.define(:name, :columns, :indexes, :primary_key_column_names)
  Column = Data.define(:name, :datatype, :nullable, :is_primary_key)
  Index = Data.define(:name, :column_names, :unique, :condition)

  class SchemaGenerator2
    def initialize(opts = {})
      config = load_config

      @core_db_connection = ActiveRecord::Base.connection
      @output_stream = $stdout

      @table_configs = config[:tables]
      @column_configs = config[:columns]
    end

    def run
      puts "Generating intermediate database schema based on Discourse #{Discourse::VERSION::STRING}"

      if @table_configs.present?
        generate_header
        generate_tables
        # generate_indirectly_ignored_columns_log
        # generate_migration_file
        # validate_migration_file
      end

      puts "", "Done"
    end

    def inspect
      "#<#{self.class}:0x#{object_id}>"
    end

    private

    def load_config
      path = File.expand_path("../config/intermediate_db.yml", __dir__)
      YAML.load_file(path, symbolize_names: true)
    end

    def generate_header
      @output_stream.puts <<~HEADER
        /*
            This file is auto-generated from the Discourse database schema.

            Instead of editing it directly, please update the `migrations/config/intermediate_db.yml` configuration file
            and re-run the `generate_schema` script to update it.
         */
      HEADER
    end

    def generate_tables
      puts "Generating tables..."

      writer = TableSchemaWriter.new(@output_stream)
      extractor = SchemaExtractor.new

      @table_configs.sort.each do |table_config|
        table = extractor.generate_table(table_config)
        writer.output_table(table)
      end
    end

    def validate_table_names!(table_names)
      existing_table_names = @core_db_connection.tables.to_set

      table_names.each do |table_name|
        if !existing_table_names.include?(table_name)
          raise "Table named '#{table_name}' not found in Discourse database"
        end
      end
    end
  end

  class SchemaExtractor
    def initialize
      @db = ActiveRecord::Base.connection
    end

    def generate_table(table_config)
      table_name, config = table_config
      config[:virtual] ? virtual_table(table_name, config) : from_database(table_name, config)
    end

    def inspect
      "#<#{self.class}:0x#{object_id}>"
    end

    private

    def from_database(table_name, config)
      primary_key_column_names = @db.primary_keys(table_name)

      columns =
        @db
          .columns(table_name)
          .map do |c|
            Column.new(
              name: c.name,
              datatype: convert_datatype(c.type),
              nullable: c.null,
              is_primary_key: primary_key_column_names.include?(c.name),
            )
          end

      Table.new(table_name, columns, indexes(config), primary_key_column_names)
    end

    def virtual_table(table_name, config)
      primary_key_column_names = Array.wrap(config[:primary_key])

      columns =
        config[:extend].map do |c|
          Column.new(
            name: c[:name],
            datatype: convert_datatype(c[:type]),
            nullable: c.fetch(:is_null, false),
            is_primary_key: primary_key_column_names.include?(c[:name]),
          )
        end

      Table.new(table_name, columns, indexes(config), primary_key_column_names)
    end

    def convert_datatype(type)
      case type
      when :string, :inet
        "TEXT"
      else
        type.to_s.upcase
      end
    end

    def indexes(config)
      config[:indexes]&.map do |index|
        Index.new(
          name: index[:name],
          column_names: Array.wrap(index[:columns]),
          unique: index.fetch(:unique, false),
          condition: index[:condition],
        )
      end
    end
  end

  class TableSchemaWriter
    def initialize(output_stream)
      @output = output_stream
    end

    def output_table(table)
      @output.puts "CREATE TABLE #{table.name}"
      @output.puts "("
      @output.puts format_columns(table)
      @output.puts ");"
      output_indexes(table)
      @output.puts ""
    end

    private

    def format_columns(table)
      columns = table.columns
      has_composite_primary_key = table.primary_key_column_names.size > 1

      column_definitions = create_column_definitions(columns, has_composite_primary_key)

      if has_composite_primary_key
        pk_definition = table.primary_key_column_names.join(", ")
        column_definitions << "    PRIMARY KEY (#{pk_definition})"
      end

      column_definitions.join(",\n")
    end

    def create_column_definitions(columns, has_composite_primary_key)
      max_column_name_length = columns.map { |c| c.name.length }.max
      max_datatype_length = columns.map { |c| c.datatype.length }.max

      columns
        .sort_by { |c| [c.is_primary_key ? 0 : 1, c.name] }
        .map do |c|
          definition = [c.name.ljust(max_column_name_length), c.datatype.ljust(max_datatype_length)]

          definition << "NOT NULL" unless c.nullable
          definition << "PRIMARY KEY" if c.is_primary_key && !has_composite_primary_key

          definition = definition.join(" ")
          definition.strip!

          "    #{definition}"
        end
    end

    def output_indexes(table)
      return if !table.indexes

      table.indexes.each do |index|
        @output.puts ""
        @output.print "CREATE "
        @output.print "UNIQUE " if index.unique
        @output.print "INDEX #{index.name} ON #{table.name} (#{index.column_names.join(", ")})"
        @output.print " #{index.condition}" if index.condition.present?
        @output.puts ";"
      end
    end
  end
end

Migrations::SchemaGenerator2.new.run
