# frozen_string_literal: true

require "rake"
require "syntax_tree/rake_tasks"

module Migrations::Database::Schema
  class ModelWriter
    def initialize(namespace, header)
      @namespace = namespace
      @header = header.gsub(/^/, "# ")
    end

    def self.filename_for(table)
      "#{table.name.singularize}.rb"
    end

    def self.format_files(path)
      glob_pattern = File.join(path, "**/*.rb")

      system(
        "bundle",
        "exec",
        "stree",
        "write",
        glob_pattern,
        exception: true,
        out: File::NULL,
        err: File::NULL,
      )
    rescue StandardError
      raise "Failed to run `bundle exec stree write '#{glob_pattern}'`"
    end

    def output_table(table, output_stream)
      columns = table.sorted_columns

      output_stream.puts "# frozen_string_literal: true"
      output_stream.puts
      output_stream.puts @header
      output_stream.puts
      output_stream.puts "module #{@namespace}"
      output_stream.puts "  module #{to_singular_classname(table.name)}"
      output_stream.puts "    SQL = <<~SQL"
      output_stream.puts "      INSERT INTO #{escape_identifier(table.name)} ("
      output_stream.puts column_names(columns)
      output_stream.puts "      )"
      output_stream.puts "      VALUES ("
      output_stream.puts value_placeholders(columns)
      output_stream.puts "      )"
      output_stream.puts "    SQL"
      output_stream.puts
      output_stream.puts "    def self.create("
      output_stream.puts method_parameters(columns)
      output_stream.puts "    )"
      output_stream.puts "      ::Migrations::Database::IntermediateDB.insert("
      output_stream.puts "        SQL,"
      output_stream.puts insertion_arguments(columns)
      output_stream.puts "      )"
      output_stream.puts "    end"
      output_stream.puts "  end"
      output_stream.puts "end"
    end

    private

    def to_singular_classname(snake_case_string)
      snake_case_string.singularize.camelize
    end

    def column_names(columns)
      columns.map { |c| "        #{escape_identifier(c.name)}" }.join(",\n")
    end

    def value_placeholders(columns)
      indentation = "        "
      max_length = 100 - indentation.length
      placeholder = "?, "
      placeholder_count = columns.size

      current_length = 0
      placeholders = indentation.dup

      (1..placeholder_count).each do |index|
        placeholder = "?" if index == placeholder_count

        if current_length + placeholder.length > max_length
          placeholders.rstrip!
          placeholders << "\n" << indentation
          current_length = 0
        end

        placeholders << placeholder
        current_length += placeholder.length
      end

      placeholders
    end

    def method_parameters(columns)
      columns
        .map do |c|
          default_value = !c.is_primary_key && c.nullable ? " nil" : ""
          "      #{c.name}:#{default_value}"
        end
        .join(",\n")
    end

    def insertion_arguments(columns)
      columns
        .map do |c|
          argument =
            case c.datatype
            when :datetime
              "::Migrations::Database.format_datetime(#{c.name})"
            when :date
              "::Migrations::Database.format_date(#{c.name})"
            when :boolean
              "::Migrations::Database.format_boolean(#{c.name})"
            when :inet
              "::Migrations::Database.format_ip_address(#{c.name})"
            when :blob
              "::Migrations::Database.to_blob(#{c.name})"
            when :json
              "::Migrations::Database.to_json(#{c.name})"
            when :float, :integer, :numeric, :text
              c.name
            else
              raise "Unknown dataype: #{type}"
            end
          "        #{argument},"
        end
        .join("\n")
    end

    def escape_identifier(identifier)
      ::Migrations::Database::Schema.escape_identifier(identifier)
    end
  end
end
