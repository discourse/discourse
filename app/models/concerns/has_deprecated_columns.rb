# frozen_string_literal: true

module HasDeprecatedColumns
  extend ActiveSupport::Concern

  DeprecatedColumn =
    Data.define(:table_name, :column_name, :message) do
      def ==(other)
        case other
        when String
          [table_name, column_name] == other.split(".")
        when DeprecatedColumn
          [table_name, column_name] == [other.table_name, other.column_name]
        else
          false
        end
      end
    end

  class_methods do
    def deprecate_column(column_name, drop_from:, raise_error: false, message: nil)
      message = message.presence || "column `#{column_name}` is deprecated."

      Discourse.deprecated_columns << DeprecatedColumn.new(table_name, column_name.to_s, message)

      define_method(column_name) do
        Discourse.deprecate(message, drop_from: drop_from, raise_error: raise_error)
        super()
      end

      define_method("#{column_name}=") do |value|
        Discourse.deprecate(message, drop_from: drop_from, raise_error: raise_error)
        super(value)
      end
    end
  end
end
