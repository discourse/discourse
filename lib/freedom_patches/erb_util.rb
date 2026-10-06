# frozen_string_literal: true

# Repair invalid UTF-8 before HTML escaping, including strings from objects' `to_s` methods.
# Otherwise, escaping can raise or copy invalid bytes into the response body.
module FreedomPatches
  module ErbUtil
    def unwrapped_html_escape(value)
      value = value.to_s
      return super(value) if value.html_safe?
      super(tidy_bytes(value))
    end

    def html_escape_once(value)
      super(tidy_bytes(value.to_s))
    end

    private

    def tidy_bytes(value)
      return value if value.valid_encoding?
      ActiveSupport::Multibyte::Unicode.tidy_bytes(value)
    end
  end
end

ERB::Util.singleton_class.prepend(FreedomPatches::ErbUtil)
ERB::Util.prepend(FreedomPatches::ErbUtil)
