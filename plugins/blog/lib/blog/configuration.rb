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
    def self.custom_domain?
      SiteSetting.blog_url.present? && URI(SiteSetting.blog_url).host != Discourse.current_hostname
    rescue URI::InvalidURIError
      false
    end

    def self.origin
      custom_domain? ? SiteSetting.blog_url : Discourse.base_url_no_prefix
    end

    def self.base_url
      custom_domain? ? SiteSetting.blog_url : "#{Discourse.base_url}#{PATH_PREFIX}"
    end

    def self.url(path = "", preview_token: nil)
      url = "#{base_url}#{path}"
      return url if preview_token.blank?
      "#{url}#{path.include?("?") ? "&" : "?"}#{{ blog_theme_preview: preview_token }.to_query}"
    end

    # The reader keeps the prefix on a custom domain too, so one client route serves both modes.
    def self.review_url
      "#{custom_domain? ? origin : Discourse.base_url}#{PATH_PREFIX}/review"
    end

    def self.blog_host?(request)
      UpcomingChanges.enabled?(:blog_enabled) && custom_domain? && request.host == URI(origin).host
    end

    # Whether a public blog page may be served for this request in the current mode.
    def self.blog_request?(request)
      public_enabled? && (!custom_domain? || blog_host?(request))
    end

    # The request path relative to the blog root, matching stored article paths.
    def self.relative_path(request)
      return request.path_info if custom_domain?
      request.path_info.delete_prefix(PATH_PREFIX).presence || "/"
    end

    def self.public_enabled?
      UpcomingChanges.enabled?(:blog_enabled) && !SiteSetting.login_required &&
        !SiteSetting.secure_uploads && !SiteSetting.prevent_anons_from_downloading_files
    end
  end
end
