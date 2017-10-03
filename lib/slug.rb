# encoding: utf-8

module Slug

  CHAR_FILTER_REGEXP = /[:\/\?#\[\]@!\$&'\(\)\*\+,;=_\.~%\\`^\s|\{\}"<>]+/ # :/?#[]@!$&'()*+,;=_.~%\`^|{}"<>
  MAX_SLUG_LENGTH = 255

  def self.for(string, default = 'topic')
    slug =
      case (SiteSetting.slug_generation_method || :ascii).to_sym
      when :ascii then self.ascii_generator(string)
      when :encoded then self.encoded_generator(string)
      when :none then self.none_generator(string)
      end
    # Reject slugs that only contain numbers, because they would be indistinguishable from id's.
    slug = (slug =~ /[^\d]/ ? slug : '')
    slug = slug.length >= MAX_SLUG_LENGTH ? '' : slug
    slug.blank? ? default : slug
  end

  def self.sanitize(string)
    self.encoded_generator(string, downcase: false)
  end

  private

  def self.ascii_generator(string)
    string.tr("'", "")
      .parameterize
      .tr("_", "-")
  end

  def self.encoded_generator(string, downcase: true)
    # This generator will sanitize almost all special characters,
    # including reserved characters from RFC3986.
    # See also URI::REGEXP::PATTERN.
    string = string.strip
      .gsub(/\s+/, '-')
      .gsub(CHAR_FILTER_REGEXP, '')
      .squeeze('-') # squeeze continuous dashes to prettify slug
      .gsub(/\A-+|-+\z/, '') # remove possible trailing and preceding dashes
    downcase ? string.downcase : string
  end

  def self.none_generator(string)
    ''
  end
end
