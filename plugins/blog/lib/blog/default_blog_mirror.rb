# frozen_string_literal: true

module ::Blog
  # Until blogs are edited in the admin, the blog settings remain the source of
  # truth for the default blog, so its row copies them. Effective values are
  # copied, so settings overridden in the environment apply.
  module DefaultBlogMirror
    COLUMNS = {
      blog_title: :name,
      blog_description: :description,
      blog_about: :about,
      blog_url: :url,
      blog_category: :category_id,
      blog_path_format: :path_format,
      blog_posts_per_page: :posts_per_page,
    }.freeze

    def self.setting?(name)
      COLUMNS.key?(name)
    end

    # Settings were never validated against the model, so a value it would reject
    # must not stop a setting from saving or a deploy from finishing.
    def self.sync!
      blog = Instance.find_or_initialize_by(is_default: true) { |new_blog| new_blog.slug = "blog" }
      blog.assign_attributes(COLUMNS.to_h { |setting, column| [column, SiteSetting.get(setting)] })
      # Activation writes the row now. A row created here, on a site upgrading
      # past the blogs table, starts from the theme the old code activated.
      blog.active_theme = PluginStore.get(BlogTheme::STORE, "active") if blog.new_record?
      blog.save!(validate: false)
    end
  end
end
