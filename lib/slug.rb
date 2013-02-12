# encoding: utf-8

# Generates a slug. This is annoying beacuse it's duplicating what the javascript 
# does, but on the other hand slugs are never matched so it's okay if they differ
# a little.
module Slug

  def self.for(string)
    str = string.dup.strip.downcase
    
    # The characters we want to replace with a hyphen
    str.tr!("·/_,:;.", "\-")

    # Convert to ASCII or remove if transliteration is unknown.
    str = ActiveSupport::Inflector.transliterate(str, '')
    
    # Remove everything except alphanumberic, space, and hyphen characters.
    str.gsub!(/[^a-z0-9 -]/, '')
    
    # Replace multiple spaces with one hyphen.
    str.gsub!(/\s+/, '-')
    
    # Replace multiple hyphens with one hyphen.
    str.gsub!(/\-+/, '-')
    
    # Remove leading and trailing hyphens
    str.gsub!(/^-|-$/, '')

    str
  end

end
