# encoding: utf-8

# Generates a slug. This is annoying because it's duplicating what the javascript
# does, but on the other hand slugs are never matched so it's okay if they differ
# a little.
module Slug

  def self.for(string)
    slug = string.parameterize.gsub("_", "-")
    slug =~ /[^\d]/ ? slug : '' # Reject slugs that only contain numbers, because they would be indistinguishable from id's.
  end

end
