# encoding: utf-8

module Slug

  CHAR_FILTER_REGEXP = /[:\/\?#\[\]@!\$&'\(\)\*\+,;=_\.~%\\`^\s|\{\}"<>]+/ # :/?#[]@!$&'()*+,;=_.~%\`^|{}"<>
  MAX_LENGTH = 255

  def self.for(string, default = 'topic', max_length = MAX_LENGTH)
    string = string.gsub(/:([\w\-+]+(?::t\d)?):/, '') if string.present? # strip emoji strings

    slug =
      case (SiteSetting.slug_generation_method || :ascii).to_sym
      when :ascii then self.ascii_generator(string)
      when :encoded then self.encoded_generator(string)
      when :none then self.none_generator(string)
      end
    # Reject slugs that only contain numbers, because they would be indistinguishable from id's.
    slug = (slug =~ /[^\d]/ ? slug : '')
    slug = self.prettify_slug(slug, max_length: max_length)
    slug.blank? ? default : slug
  end

  def self.sanitize(string, downcase: false, max_length: MAX_LENGTH)
    slug = self.encoded_generator(string, downcase: downcase)
    self.prettify_slug(slug, max_length: max_length)
  end

  private

  def self.prettify_slug(slug, max_length:)
    slug
      .tr("_", "-")
      .truncate(max_length, omission: '')
      .squeeze('-') # squeeze continuous dashes to prettify slug
      .gsub(/\A-+|-+\z/, '') # remove possible trailing and preceding dashes
  end

  def self.ascii_generator(string)
    string.tr("'", "").parameterize
  end

  def self.encoded_generator(string, downcase: true)
    # This generator will sanitize almost all special characters,
    # including reserved characters from RFC3986.
    # See also URI::REGEXP::PATTERN.
    string = string.strip
      .gsub(/\s+/, '-')
      .gsub(CHAR_FILTER_REGEXP, '')

    downcase ? string.downcase : string
  end

  def self.none_generator(string)
    ''
  end
end
