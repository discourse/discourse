# frozen_string_literal: true

module Migrations::Database::Schema
  class TableWriter
    def initialize(output_stream)
      @output = output_stream
    end

    def output_file_header(header)
      @output.puts header.gsub(/^/, "-- ")
      @output.puts
    end

    def output_table(table)
      output_create_table_statement(table)
      output_columns(table)
      output_primary_key(table)
      output_indexes(table)
      @output.puts ""
    end

    private

    def output_create_table_statement(table)
      @output.puts "CREATE TABLE #{escape_identifier(table.name)}"
      @output.puts "("
    end

    def output_columns(table)
      column_definitions = create_column_definitions(table)
      column_definitions << "" if table.primary_key_column_names.size > 1
      @output.puts column_definitions.join(",\n")
    end

    def output_primary_key(table)
      if table.primary_key_column_names.size > 1
        pk_definition =
          table.primary_key_column_names.map { |name| escape_identifier(name) }.join(", ")
        @output.puts "    PRIMARY KEY (#{pk_definition})"
      end
      @output.puts ");"
    end

    def create_column_definitions(table)
      columns = table.sorted_columns
      has_composite_primary_key = table.primary_key_column_names.size > 1

      max_column_name_length = columns.map { |c| escape_identifier(c.name).length }.max
      max_datatype_length = columns.map { |c| convert_datatype(c.datatype).length }.max

      columns.map do |c|
        definition = [
          escape_identifier(c.name).ljust(max_column_name_length),
          convert_datatype(c.datatype).ljust(max_datatype_length),
        ]

        if c.is_primary_key && !has_composite_primary_key
          definition << "NOT NULL" if c.datatype != :integer
          definition << "PRIMARY KEY"
        else
          definition << "NOT NULL" unless c.nullable
        end

        definition = definition.join(" ")
        definition.strip!

        "    #{definition}"
      end
    end

    def convert_datatype(type)
      case type
      when :blob, :boolean, :date, :datetime, :float, :integer, :numeric, :text
        type.to_s.upcase
      when :inet
        "INET_TEXT"
      when :json
        "JSON_TEXT"
      else
        raise "Unknown datatype: #{type}"
      end
    end

    def escape_identifier(identifier)
      ::Migrations::Database::Schema.escape_identifier(identifier)
    end

    def output_indexes(table)
      return unless table.indexes

      table.indexes.each do |index|
        index_name = escape_identifier(index.name)
        table_name = escape_identifier(table.name)
        column_names = index.column_names.map { |name| escape_identifier(name) }

        @output.puts ""
        @output.print "CREATE "
        @output.print "UNIQUE " if index.unique
        @output.print "INDEX #{index_name} ON #{table_name} (#{column_names.join(", ")})"
        @output.print " #{index.condition}" if index.condition.present?
        @output.puts ";"
      end
    end
  end
end
