# encoding: utf-8

# Generates a slug. This is annoying because it's duplicating what the javascript
# does, but on the other hand slugs are never matched so it's okay if they differ
# a little.
module Slug

  def self.for(string)
    string.parameterize.gsub("_", "-")
  end

end
