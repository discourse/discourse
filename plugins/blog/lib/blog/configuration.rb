# frozen_string_literal: true

module ::Blog
  # Where the public blog lives and whether a request belongs to it.
  module Configuration
    ASSET_PREFIXES = %w[
      plugins
      uploads
      assets
      stylesheets
      javascripts
      font
      images
      extra-locales
      svg-sprite
    ].freeze
    PATH_PREFIX = "/blog"

    def self.asset_path?(path)
      ASSET_PREFIXES.include?(path.split("/")[1])
    end

    # Without a custom domain the blog lives under PATH_PREFIX on the forum.
    def self.custom_domain?(blog = Instance.default_blog)
      blog.url.present? && URI(blog.url).host != Discourse.current_hostname
    rescue URI::InvalidURIError
      false
    end

    def self.origin(blog = Instance.default_blog)
      custom_domain?(blog) ? blog.url : Discourse.base_url_no_prefix
    end

    def self.base_url(blog = Instance.default_blog)
      custom_domain?(blog) ? blog.url : "#{Discourse.base_url}#{path_prefix(blog)}"
    end

    # Other blogs without a custom domain live under the default blog's prefix,
    # at their slug, which is why slugs are reserved segments.
    def self.path_prefix(blog)
      blog.is_default? ? PATH_PREFIX : "#{PATH_PREFIX}/#{blog.slug}"
    end

    def self.url(path = "", blog: Instance.default_blog, preview_token: nil)
      url = "#{base_url(blog)}#{path}"
      return url if preview_token.blank?
      "#{url}#{path.include?("?") ? "&" : "?"}#{{ blog_theme_preview: preview_token }.to_query}"
    end

    # The reader keeps the prefix on a custom domain too, so one client route serves both modes.
    def self.review_url(blog = Instance.default_blog)
      "#{custom_domain?(blog) ? origin(blog) : Discourse.base_url}#{PATH_PREFIX}/review"
    end

    # Runs on every request to the site, so it reads only the cached blog list.
    def self.blog_for_host(host)
      Instance.cached.find { |blog| custom_domain?(blog) && URI(blog.url).host == host }
    end

    def self.blog_host?(request)
      UpcomingChanges.enabled?(:blog_enabled) && blog_for_host(request.host).present?
    end

    # The blog a forum path belongs to, whether or not that blog is served there.
    def self.blog_for_path(path)
      return if !path.match?(%r{\A#{PATH_PREFIX}(?:/|\z)})
      segment = path.delete_prefix(PATH_PREFIX).split("/")[1]
      Instance.cached.find { |blog| !blog.is_default? && blog.slug == segment } ||
        Instance.default_blog
    end

    # The blog a request is for: by host on a custom domain, otherwise by path.
    def self.blog_for(request)
      return if !UpcomingChanges.enabled?(:blog_enabled)
      blog_for_host(request.host) || blog_for_path(request.path_info)
    end

    # Whether a public blog page may be served for this request. A blog with a
    # custom domain is only served there; its forum path redirects instead.
    def self.blog_request?(request, blog = blog_for(request))
      return false if !public_enabled?
      return false if blog.nil?
      custom_domain?(blog) ? blog_host?(request) : !blog_host?(request)
    end

    # The review reader is not tied to one blog: its link carries a token.
    def self.review_request?(request)
      return false if !public_enabled?
      blog_host?(request) || Instance.cached.any? { |blog| !custom_domain?(blog) }
    end

    # The origin pages are served from for this request, for same-origin checks.
    def self.request_origin(request)
      blog = blog_for_host(request.host)
      blog ? origin(blog) : Discourse.base_url_no_prefix
    end

    # The request path relative to the blog root, matching stored article paths.
    def self.relative_path(request, blog)
      return request.path_info if custom_domain?(blog)
      request.path_info.delete_prefix(path_prefix(blog)).presence || "/"
    end

    def self.public_enabled?
      UpcomingChanges.enabled?(:blog_enabled) && !SiteSetting.login_required &&
        !SiteSetting.secure_uploads && !SiteSetting.prevent_anons_from_downloading_files
    end
  end
end
