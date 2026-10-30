# frozen_string_literal: true

module ::Blog
  class ColorValidator
    def initialize(*)
    end

    def valid_value?(value)
      value.to_s.match?(/\A[0-9a-fA-F]{6}\z/)
    end

    def error_message
      I18n.t("blog.errors.color")
    end
  end
end
