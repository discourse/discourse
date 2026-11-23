# frozen_string_literal: true

module ::Blog
  class PathFormatValidator
    def initialize(opts = {})
      @opts = opts
    end

    # The setting is the default blog's format. Other blogs live at /blog/<slug>,
    # so a format that always starts with one of their slugs blocks every new article.
    def valid_value?(value)
      format = PathFormat.new(value)
      return false if !format.valid?
      @blog_slug =
        Instance.cached.reject(&:is_default?).map(&:slug).find { format.fixed_first_segment?(it) }
      @blog_slug.nil?
    end

    def error_message
      return I18n.t("blog.errors.path_format_blog_slug", slug: @blog_slug) if @blog_slug
      I18n.t("blog.errors.path_format")
    end
  end
end
