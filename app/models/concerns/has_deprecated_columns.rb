# frozen_string_literal: true

module HasDeprecatedColumns
  extend ActiveSupport::Concern

  class_methods do
    def deprecate_column(column_name, drop_from:, raise_error: false, message: nil)
      message = message.presence || "column `#{column_name}` is deprecated."

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
