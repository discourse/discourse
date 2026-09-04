# frozen_string_literal: true

class BrowserPageviewEventLanguageNormalizer
  def self.normalize(language)
    return if language.nil?

    tag = I18n::Locale::Tag::Rfc4646.tag(language.tr("_", "-"))
    return "" if tag&.language.nil?

    primary_language = tag.language.split("-", 2).first
    [primary_language, tag.script].compact.join("-")
  end
end
