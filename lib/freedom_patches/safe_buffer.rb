# frozen_string_literal: true

# For some reason safe buffer is getting invalid encoding in some cases
# we work around the issue and log the problems
#
# The alternative is a broken website when this happens

module FreedomPatches
  module SafeBuffer
    def concat(value, raise_encoding_err = false)
      super(value)
    rescue Encoding::CompatibilityError
      raise if raise_encoding_err

      encoding_diags =
        +"internal encoding #{Encoding.default_internal}, external encoding #{Encoding.default_external}"
      if encoding != Encoding::UTF_8
        encoding_diags << " my encoding is #{encoding} "
        force_encoding("UTF-8")
        unless valid_encoding?
          encode!("utf-16", "utf-8", invalid: :replace)
          encode!("utf-8", "utf-16")
        end
        Rails.logger.warn(
          "Encountered a non UTF-8 string in SafeBuffer - #{self} - #{encoding_diags}",
        )
      end
      if value.encoding != Encoding::UTF_8
        encoding_diags << " attempted to append encoding  #{value.encoding} "
        value = value.dup.force_encoding("UTF-8").scrub
        Rails.logger.warn(
          "Attempted to concat a non UTF-8 string in SafeBuffer - #{value} - #{encoding_diags}",
        )
      end
      concat(value, _raise = true)
    end

    ActiveSupport::SafeBuffer.prepend(self)
    ActiveSupport::SafeBuffer.class_eval("alias << concat")
  end
end
