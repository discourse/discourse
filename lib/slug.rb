# encoding: utf-8
# frozen_string_literal: true

module Slug
  CHAR_FILTER_REGEXP = /[:\/\?#\[\]@!\$&'\(\)\*\+,;=_\.~%\\`^\s|\{\}"<>]+/ # :/?#[]@!$&'()*+,;=_.~%\`^|{}"<>
  MAX_LENGTH = 255

  def self.for(string, default = "topic", max_length = MAX_LENGTH, method: nil)
    string = string.gsub(/:([\w\-+]+(?::t\d)?):/, "") if string.present? # strip emoji strings
    method = (method || SiteSetting.slug_generation_method || :ascii).to_sym
    max_length = 9999 if method == :encoded # do not truncate encoded slugs

    slug =
      case method
      when :ascii
        self.ascii_generator(string)
      when :encoded
        self.encoded_generator(string)
      when :none
        self.none_generator(string)
      end

    slug = self.prettify_slug(slug, max_length: max_length)
    (slug.blank? || slug_is_only_numbers?(slug)) ? default : slug
  end

  private

  def self.slug_is_only_numbers?(slug)
    (slug =~ /[^\d]/).blank?
  end

  def self.prettify_slug(slug, max_length:)
    # Reject slugs that only contain numbers, because they would be indistinguishable from id's.
    slug = (slug_is_only_numbers?(slug) ? "" : slug)

    slug
      .tr("_", "-")
      .truncate(max_length, omission: "")
      .squeeze("-") # squeeze continuous dashes to prettify slug
      .gsub(/\A-+|-+\z/, "") # remove possible trailing and preceding dashes
  end

  def self.ascii_generator(string)
    I18n.with_locale(SiteSetting.default_locale) { string.tr("'", "").parameterize }
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
