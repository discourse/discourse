# encoding: utf-8


module Slug

  # Generates slug according to site setting
  def self.for(string)
    return '' if SiteSetting.suppress_slug

    self.safe_for(string)
  end

  # Ignores the suppress site setting, always try to generate something useful
  # If custom slug is passed, this method should be used
  def self.safe_for(string)
    slug = string.gsub("'", "").parameterize
    slug.gsub!("_", "-")
    # TODO review if ja should use this
    # ko asked for it to be removed
    if ['zh_CN', 'ja'].include?(SiteSetting.default_locale)
      unless defined? Stringex
        require 'stringex_lite'
      end
      slug = string.to_url
    end
    slug =~ /[^\d]/ ? slug : '' # Reject slugs that only contain numbers, because they would be indistinguishable from id's.
  end

end
