# frozen_string_literal: true

module Migrations
  module Database
    module Schema
      class ModelWriter
        def initialize(model_namespace, enum_namespace, header)
          @model_namespace = model_namespace
          @enum_namespace = enum_namespace
          @header = header.gsub(/^/, "# ")
          @namespace_parts = model_namespace.split("::")
          @innermost = @namespace_parts.last
          @base_indent = "  " * (@namespace_parts.size - 1)
        end

        def self.filename_for(table)
          "#{table.name.singularize}.rb"
        end

        def output_table(table, output_stream, custom_code: nil)
          @out = output_stream
          module_name = Helpers.to_singular_classname(table.name)
          columns = table.sorted_columns

          emit "# frozen_string_literal: true"
          emit
          emit @header
          emit
          @namespace_parts.each { |part| emit "module #{part}" }
          emit "  module #{module_name}"
          emit "    SQL = <<~SQL"
          emit "      INSERT INTO #{escape_identifier(table.name)} ("
          emit column_names(columns)
          emit "      )"
          emit "      VALUES ("
          emit "        #{value_placeholders(columns)}"
          emit "      )"
          emit "    SQL"
          emit "    private_constant :SQL"
          emit

          if table.model_mode == :extended
            emit "    # -- custom code --"
            emit custom_code if custom_code.present?
            emit "    # -- end custom code --"
            emit
          end

          emit method_documentation(table.name, columns)
          emit "    def self.create("
          emit method_parameters(columns)
          emit "    )"
          emit "      #{@innermost}.insert("
          emit "        SQL,"
          emit insertion_arguments(columns)
          emit "      )"
          emit "    end"
          (@namespace_parts.size + 1).times { emit "  end" }
        ensure
          @out = nil
        end

        private

        def emit(text = nil)
          if text.nil?
            @out.puts
          else
            text.each_line(chomp: true) do |line|
              @out.puts(line.empty? ? "" : "#{@base_indent}#{line}")
            end
          end
        end

        def column_names(columns)
          columns.map { |c| "        #{escape_identifier(c.name)}" }.join(",\n")
        end

        def value_placeholders(columns)
          (["?"] * columns.size).join(", ")
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
            module_name = Helpers.to_singular_classname(enum.name)
            first_const = Helpers.to_const_name(enum.values.min_by { |_k, v| v }.first)

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
                  "Database.format_datetime(#{c.name})"
                when :date
                  "Database.format_date(#{c.name})"
                when :boolean
                  "Database.format_boolean(#{c.name})"
                when :inet
                  "Database.format_ip_address(#{c.name})"
                when :blob
                  "Database.to_blob(#{c.name})"
                when :json
                  "Database.to_json(#{c.name})"
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
          Helpers.escape_identifier(identifier)
        end
      end
    end
  end
end
