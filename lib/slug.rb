# encoding: utf-8


module Slug

  def self.for(string)
    slug = string.gsub("'", "").parameterize
    slug.gsub!("_", "-")
    if ['zh_CN', 'ja', 'ko'].include?(SiteSetting.default_locale)
      unless defined? Stringex
        require 'stringex_lite'
      end
      slug = string.to_url
    end
    slug =~ /[^\d]/ ? slug : '' # Reject slugs that only contain numbers, because they would be indistinguishable from id's.
  end

end
