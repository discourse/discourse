# frozen_string_literal: true

# Rails 8.1 stopped repairing invalid UTF-8 before it escapes a string. Without this patch
# `html_escape_once` raises `ArgumentError` and `html_escape` copies the invalid bytes into the
# response body. Text from remote HTTP responses, email parts, file names and request headers
# reaches these helpers without a database round trip, so it can still hold invalid bytes.
module FreedomPatches
  module ErbUtil
    def unwrapped_html_escape(value)
      return super if value.is_a?(String) && value.html_safe?
      super(tidy_bytes(value))
    end

    def html_escape_once(value)
      super(tidy_bytes(value))
    end

    private

    def tidy_bytes(value)
      return value if !value.is_a?(String) || value.valid_encoding?
      ActiveSupport::Multibyte::Unicode.tidy_bytes(value)
    end
  end
end

ERB::Util.singleton_class.prepend(FreedomPatches::ErbUtil)
ERB::Util.prepend(FreedomPatches::ErbUtil)
