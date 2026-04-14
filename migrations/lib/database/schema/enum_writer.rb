# frozen_string_literal: true

module Migrations
  module Database
    module Schema
      class EnumWriter
        def initialize(namespace, header)
          @namespace = namespace
          @header = header.gsub(/^/, "# ")
          @namespace_parts = namespace.split("::")
          @base_indent = "  " * (@namespace_parts.size - 1)
        end

        def self.filename_for(enum)
          "#{enum.name.downcase.underscore}.rb"
        end

        def output_enum(enum, output_stream)
          @out = output_stream
          module_name = Helpers.to_singular_classname(enum.name)

          emit "# frozen_string_literal: true"
          emit
          emit @header
          emit
          @namespace_parts.each { |part| emit "module #{part}" }
          emit "  module #{module_name}"
          emit "    extend Migrations::Enum"
          emit
          emit enum_values(enum.values)
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

        def enum_values(values)
          values
            .sort_by { |_k, v| v }
            .map do |name, value|
              value = %Q|"#{value}"| if value.is_a?(String)
              "    #{Helpers.to_const_name(name)} = #{value}"
            end
            .join("\n")
        end
      end
    end
  end
end
