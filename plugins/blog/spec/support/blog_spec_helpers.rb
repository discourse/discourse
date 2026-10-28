# frozen_string_literal: true

module BlogSpecHelpers
  BLOG_HOST = "blog.example.com"
  DISCUSSION_HOST = "test.localhost"
  BLOG_HOSTNAMES = [DISCUSSION_HOST, BLOG_HOST].freeze

  # Stubs both hostnames and enables the blog, optionally wiring its categories.
  def enable_blog!(category: nil, drafts: nil)
    RailsMultisite::ConnectionManagement.stubs(:current_db_hostnames).returns(BLOG_HOSTNAMES)
    SiteSetting.blog_enabled = true
    SiteSetting.blog_url = "https://#{BLOG_HOST}"
    SiteSetting.blog_category = category.id if category
    SiteSetting.blog_drafts_category = drafts.id if drafts
  end
end

RSpec.configure { |config| config.include(BlogSpecHelpers) }
