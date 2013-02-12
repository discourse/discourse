# encoding: utf-8

# Generates a slug. This is annoying beacuse it's duplicating what the javascript 
# does, but on the other hand slugs are never matched so it's okay if they differ
# a little.
module Slug

  def self.for(string)

    str = string.dup
    str.gsub!(/^\s+|\s+$/, '')
    str.downcase!

    # The characters we want to replace with a hyphen
    str.tr!("·/_,:;.", "\-")

    # Convert to ASCII or remove if transliteration is unknown.
    str = ActiveSupport::Inflector.transliterate(str, '')

    str.gsub!(/[^a-z0-9 -]/, '')
    str.gsub!(/\s+/, '-')
    str.gsub!(/\-+/, '-')
    str.gsub!(/^-|-$/, '')

    str
  end

end
