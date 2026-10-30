# frozen_string_literal: true

module BlogSpecHelpers
  BLOG_HOST = "blog.example.com"
  DISCUSSION_HOST = "test.localhost"
  BLOG_HOSTNAMES = [DISCUSSION_HOST, BLOG_HOST].freeze

  # Enables the blog, optionally wiring its categories. A custom domain stubs both
  # hostnames; without one the blog is served under /blog on the forum.
  def enable_blog!(category: nil, drafts: nil, custom_domain: true)
    SiteSetting.blog_enabled = true
    if custom_domain
      RailsMultisite::ConnectionManagement.stubs(:current_db_hostnames).returns(BLOG_HOSTNAMES)
      SiteSetting.blog_url = "https://#{BLOG_HOST}"
    end
    SiteSetting.blog_category = category.id if category
    SiteSetting.blog_drafts_category = drafts.id if drafts
  end
end

RSpec.configure { |config| config.include(BlogSpecHelpers) }
