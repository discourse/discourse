# encoding: utf-8

module Slug

  def self.for(string)
    slug = string.gsub("'", "").parameterize
    slug.gsub!("_", "-")
    slug =~ /[^\d]/ ? slug : '' # Reject slugs that only contain numbers, because they would be indistinguishable from id's.
  end

end
