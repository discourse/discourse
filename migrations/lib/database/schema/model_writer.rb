# frozen_string_literal: true

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

    def output_table(table, output_stream, custom_code: nil)
      module_name = ::Migrations::Database::Schema::Helpers.to_singular_classname(table.name)
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

      if table.model_mode == :extended
        output_stream.puts "    # -- custom code --"
        output_stream.puts custom_code if custom_code.present?
        output_stream.puts "    # -- end custom code --"
        output_stream.puts
      end

      output_stream.puts method_documentation(table.name, columns)
      output_stream.puts "    def self.create("
      output_stream.puts method_parameters(columns)
      output_stream.puts "    )"
      output_stream.puts "      ::#{@model_namespace}.insert("
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
      max_name_length = columns.map { |c| c.name.length }.max
      see_references = []

      param_lines = columns.map { |c| param_line_for(c, max_name_length, see_references) }

      lines = [
        "    # Creates a new `#{table_name}` record in the #{Helpers.db_label(@model_namespace)}.",
        "    #",
        *param_lines,
        "    #",
        "    # @return [void]",
      ]

      if see_references.any?
        lines << "    #"
        lines.concat(see_references.map { |ref| "    # @see #{ref}" })
      end

      lines.join("\n")
    end

    def param_line_for(column, max_name_length, see_references)
      param_name = column.name.ljust(max_name_length)
      datatypes = datatypes_for_documentation(column)
      line = +"    # @param #{param_name}   [#{datatypes}]"

      if (enum = column.enum)
        module_name = ::Migrations::Database::Schema::Helpers.to_singular_classname(enum.name)
        first_const =
          ::Migrations::Database::Schema::Helpers.to_const_name(
            enum.values.min_by { |_k, v| v }.first,
          )

        line << "\n    #   Any constant from #{module_name} (e.g. #{module_name}::#{first_const})"
        see_references << "#{@enum_namespace}::#{module_name}"
      end

      line
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
      ::Migrations::Database::Schema::Helpers.escape_identifier(identifier)
    end
  end
end
