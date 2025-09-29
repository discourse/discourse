# frozen_string_literal: true

require "rake"
require "syntax_tree/rake_tasks"

module Migrations::Database::Schema
  class ModelWriter
    def initialize(model_namespace, enum_namespace, header)
      @model_namespace = model_namespace
      @enum_namespace = enum_namespace
      @header = header.gsub(/^/, "# ")
    end

    def self.filename_for(table)
      "#{table.name.singularize}.rb"
    end

    def output_table(table, output_stream)
      module_name = ::Migrations::Database::Schema.to_singular_classname(table.name)
      columns = table.sorted_columns

      output_stream.puts "# frozen_string_literal: true"
      output_stream.puts
      output_stream.puts @header
      output_stream.puts
      output_stream.puts "module #{@model_namespace}"
      output_stream.puts "  module #{module_name}"
      output_stream.puts "    SQL = <<~SQL"
      output_stream.puts "      INSERT INTO #{escape_identifier(table.name)} ("
      output_stream.puts column_names(columns)
      output_stream.puts "      )"
      output_stream.puts "      VALUES ("
      output_stream.puts value_placeholders(columns)
      output_stream.puts "      )"
      output_stream.puts "    SQL"
      output_stream.puts "    private_constant :SQL"
      output_stream.puts
      output_stream.puts method_documentation(table.name, columns)
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

    def method_documentation(table_name, columns)
      max_column_name_length = columns.map { |c| c.name.length }.max

      documentation = +"    # Creates a new `#{table_name}` record in the IntermediateDB.\n"
      documentation << "    #\n"

      param_documentation =
        columns.map do |c|
          param_name = c.name.ljust(max_column_name_length)
          datatypes = datatypes_for_documentation(c)
          "    # @param #{param_name}   [#{datatypes}]"
        end

      max_line_length = param_documentation.map(&:length).max
      see_documenation = []

      columns.each_with_index do |column, index|
        if (enum = column.enum)
          enum_module_name = ::Migrations::Database::Schema.to_singular_classname(enum.name)
          enum_value_names = enum.values.sort_by { |_k, v| v }.map(&:first)
          first_const_name = ::Migrations::Database::Schema.to_const_name(enum_value_names.first)

          enum_documentation =
            "    #   Any constant from #{enum_module_name} (e.g. #{enum_module_name}::#{first_const_name})"

          line = param_documentation[index].ljust(max_line_length)
          param_documentation[index] = "#{line}\n#{enum_documentation}"

          see_documenation << "#{@enum_namespace}::#{enum_module_name}"
        end
      end

      documentation << param_documentation.join("\n")
      documentation << "\n    #\n"
      documentation << "    # @return [void]"

      if see_documenation.any?
        documentation << "\n    #\n"
        documentation << see_documenation.map { |see| "    # @see #{see}" }.join("\n")
      end

      documentation
    end

    def datatypes_for_documentation(column)
      datatypes =
        Array(
          case column.datatype
          when :datetime, :date
            "Time"
          when :boolean
            "Boolean"
          when :inet
            "IPAddr"
          when :blob
            "String"
          when :json
            "Object"
          when :float
            "Float"
          when :integer
            "Integer"
          when :numeric
            %w[Integer String]
          when :text
            "String"
          else
            raise "Unknown datatype: #{column.datatype}"
          end,
        )

      datatypes << "nil" if column.nullable
      datatypes.join(", ")
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
              raise "Unknown datatype: #{c.datatype}"
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
