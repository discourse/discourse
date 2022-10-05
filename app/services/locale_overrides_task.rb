# frozen_string_literal: true

class LocaleOverridesTask
  SUPPORTED_TYPES = ["client","server"]
  def self.export_to_hash(type)
    if !type.in?(SUPPORTED_TYPES)
      raise Discourse::InvalidParameters,  "Unsupported type provided, must be one of #{SUPPORTED_TYPES}"
    end
    locale_file = LocaleFileChecker.new.load_default_locale_files(I18n.locale)[type.to_sym]
    overrides = TranslationOverride.where(locale: I18n.locale)
    locale_hash = Hash.new { |h,k| h[k] = h.dup.clear }
    overrides.each{|t|
      # Check if this override is in the specified hash
      # If it is go ahead and store it

      this_override_key = t.translation_key.to_s
      this_override_key_path = this_override_key.split(".")
      if (!locale_file.dig(I18n.locale.to_s, *this_override_key_path).nil?)
        # Value exists for this type, let's create the correct path for the export

        # First, use dig to create the path if it isn't already present
        locale_hash.dig(*this_override_key_path)

        # Now, use inject to set the value
        this_override_key_path[0...-1].inject(locale_hash, :fetch)[this_override_key_path.last] = t.value
      end
    }

    override_hash = {}
    override_hash[I18n.locale.to_s] = locale_hash

    override_hash
  end
end
