# encoding: utf-8

module Slug

  def self.for(string, default = 'topic')
    slug = case SiteSetting.slug_generation_method.to_sym
           when :ascii then self.ascii_generator(string)
           when :encoded then self.encoded_generator(string)
           when :none then self.none_generator(string)
           else raise Discourse::SiteSettingMissing
           end
    # Reject slugs that only contain numbers, because they would be indistinguishable from id's.
    slug = (slug =~ /[^\d]/ ? slug : '')
    slug.blank? ? default : slug
  end

  private

  def self.ascii_generator(string)
    slug = string.gsub("'", "").parameterize
    slug.gsub("_", "-")
  end

  def self.encoded_generator(string)
    # strip and sanitized RFC 3986 reserved character and blank
    string = string.strip.gsub(/\s+/, '-').gsub(/[:\/\?#\[\]@!\$\s&'\(\)\*\+,;=]+/, '')
    string = Rack::Utils.escape_path(string)
    string =~ /^-+$/ ? '' : string
  end

  def self.none_generator(string)
    ''
  end
end
