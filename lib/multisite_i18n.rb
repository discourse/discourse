# Allow us to override i18n keys based on the current site you're viewing.
module MultisiteI18n

  class << self

    # It would be nice if there was an easier way to detect if a key is missing.
    def translation_or_nil(key, opts)
      missing_text = "missing multisite translation"
      result = I18n.t(key, opts.merge(default: missing_text))
      return nil if result == missing_text
      result
    end

    def site_translate(current_site, key, opts=nil)
      opts ||= {}
      translation = MultisiteI18n.translation_or_nil("#{current_site || ""}.#{key}", opts)
      if translation.blank?
        return I18n.t(key, opts)
      else
        return translation
      end
    end

    def t(*args)
      MultisiteI18n.site_translate(RailsMultisite::ConnectionManagement.current_db, *args)
    end

    alias :translate :t
  end

end
