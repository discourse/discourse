# frozen_string_literal: true

module Slug
  CHAR_FILTER_REGEXP = /[:\/\?#\[\]@!\$&'\(\)\*\+,;=_\.~%\\`^\s|\{\}"<>]+/ # :/?#[]@!$&'()*+,;=_.~%\`^|{}"<>
  MAX_LENGTH = 255
  DIGITS_ONLY_REGEXP = /\A\d*\z/
  EDGE_DASHES_REGEXP = /\A-+|-+\z/
  private_constant :DIGITS_ONLY_REGEXP, :EDGE_DASHES_REGEXP

  def self.for(string, default = "topic", max_length = MAX_LENGTH, method: nil)
    string = string.gsub(Emoji::EMOJI_CODE_REGEXP, "") if string.present? && string.include?(":")
    method = (method || SiteSetting.slug_generation_method || :ascii).to_sym
    max_length = 9999 if method == :encoded # do not truncate encoded slugs

    slug =
      case method
      when :ascii
        ascii_generator(string)
      when :encoded
        encoded_generator(string)
      when :none
        none_generator(string)
      end

    slug = prettify_slug(slug, max_length: max_length)
    slug.presence || default
  end

  private

  def self.slug_is_only_numbers?(slug)
    slug.blank? || DIGITS_ONLY_REGEXP.match?(slug)
  end

  def self.prettify_slug(slug, max_length:)
    # Reject slugs that only contain numbers, because they would be indistinguishable from id's.
    return "" if slug_is_only_numbers?(slug)

    slug = slug.tr("_", "-") if slug.include?("_")
    slug = slug.truncate(max_length, omission: "") if slug.length > max_length
    slug = slug.squeeze("-") if slug.include?("--")
    slug = slug.gsub(EDGE_DASHES_REGEXP, "") if slug.start_with?("-") || slug.end_with?("-")

    slug_is_only_numbers?(slug) ? "" : slug
  end

  def self.ascii_generator(string)
    cleaned = string.include?("'") ? string.delete("'") : string
    target_locale = SiteSetting.default_locale.to_sym
    if I18n.locale == target_locale
      cleaned.parameterize
    else
      I18n.with_locale(target_locale) { cleaned.parameterize }
    end
  end

  def self.encoded_generator(string, downcase: true)
    # This generator will sanitize almost all special characters,
    # including reserved characters from RFC3986.
    # See also URI::REGEXP::PATTERN.
    string = string.strip.gsub(/\s+/, "-").gsub(CHAR_FILTER_REGEXP, "")

    string = string.downcase if downcase

    CGI.escape(string)
  end

  def self.none_generator(string)
    ""
  end
end
