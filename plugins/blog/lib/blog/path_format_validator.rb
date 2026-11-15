# frozen_string_literal: true

module ::Blog
  class PathFormatValidator
    def initialize(opts = {})
      @opts = opts
    end

    def valid_value?(value)
      PathFormat.new(value).valid?
    end

    def error_message
      I18n.t("blog.errors.path_format")
    end
  end
end
