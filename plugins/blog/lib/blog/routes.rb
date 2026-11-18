# frozen_string_literal: true

module Blog
  # Prepended from plugin.rb so these routes are matched before core's routes. Rails
  # draws prepended blocks before loading any routes file, so they can't live in
  # config/routes.rb.
  module Routes
    ON_BLOG_HOST = ->(request) do
      Configuration.blog_host?(request) && !Configuration.asset_path?(request.path)
    end
    ON_PATH_PREFIX = ->(_) do
      UpcomingChanges.enabled?(:blog_enabled) && !Configuration.custom_domain?
    end
    MOVED_TO_CUSTOM_DOMAIN = ->(_) do
      UpcomingChanges.enabled?(:blog_enabled) && Configuration.custom_domain?
    end

    # Article paths share their first segment with the routes below in both hosting modes
    # (sites can switch modes), so articles may never claim them. A spec checks this covers every route.
    RESERVED_SEGMENTS = %w[
      about
      author
      blog
      blog-custom.js
      blog-highlight
      blog-theme.css
      feed
      feed.xml
      page
      posts
      posts.atom
      posts.rss
      review
      robots.txt
      rss
      session
      sitemap
      tag
    ].freeze
    # Only the bare listing is routed, leaving dated "/archive/..." article paths available.
    RESERVED_EXACT_SEGMENTS = %w[archive].freeze

    ARTICLES =
      proc do
        get "/" => "articles#index"
        get "/archive" => "articles#index", :defaults => { archive: true }
        get "/tag/:tag" => "articles#index"
        get "/author/:username" => "articles#index",
            :constraints => {
              username: %r{[^/]+},
            },
            :format => false
        get "/about" => "articles#about"
        get "/blog-theme.css" => "articles#theme_css", :format => false
        get "/blog-highlight/:version.js" => "articles#highlight_js", :format => false
        get "/blog-custom.js" => "articles#theme_js", :format => false
        get "/feed.xml" => "articles#feed", :defaults => { format: "rss" }, :format => false
        get "/sitemap" => "articles#sitemap", :format => true, :constraints => { format: :xml }
        get "/*path" => "articles#show", :format => false
      end

    DRAW =
      proc do
        scope module: :blog do
          constraints(ON_BLOG_HOST) do
            get "/session/csrf" => "review_reader#csrf"
            get "/blog/review" => "review_reader#show"
            post "/blog/review/feedback" => "review_reader#feedback"
            get "/review" =>
                  redirect { |_, request| request.fullpath.sub("/review", "/blog/review") },
                :format => false
            get "/posts" => redirect { "#{Configuration.base_url}/" }, :format => false
            # Feed and pagination URLs that other blog engines publish, kept for readers and links.
            %w[/posts.rss /posts.atom /rss /feed].each do |path|
              get path => redirect { "#{Configuration.base_url}/feed.xml" }, :format => false
            end
            get "/page/:page" =>
                  redirect { |params, _|
                    page = params[:page].to_i
                    "#{Configuration.base_url}/#{"?page=#{page}" if page > 1}"
                  },
                :constraints => {
                  page: /\d+/,
                },
                :format => false
            get "/robots.txt" => "articles#robots",
                :defaults => {
                  format: "text",
                },
                :format => false
            instance_exec(&ARTICLES)
          end

          scope Configuration::PATH_PREFIX do
            constraints(ON_PATH_PREFIX) do
              get "/review" => "review_reader#show"
              post "/review/feedback" => "review_reader#feedback"
              instance_exec(&ARTICLES)
            end

            # Temporary, since a site can drop its custom domain and browsers cache 301s.
            constraints(MOVED_TO_CUSTOM_DOMAIN) do
              get "/(*path)" =>
                    redirect(status: 302) { |_, request| Routes.custom_domain_url(request) },
                  :format => false
            end
          end
        end

        # The themes list is served by Blog::ThemesController, which renders the app for page loads.
        %w[appearance identity themes/new themes/import/new themes/:id/edit].each do |path|
          get "/admin/plugins/blog/#{path}" => "admin/plugins#show",
              :defaults => {
                plugin_id: "blog",
              },
              :constraints => AdminConstraint.new
        end

        mount Engine, at: "/"
      end

    private_constant :ON_BLOG_HOST, :ON_PATH_PREFIX, :MOVED_TO_CUSTOM_DOMAIN, :ARTICLES

    def self.custom_domain_url(request)
      path = request.path_info.delete_prefix(Configuration::PATH_PREFIX).presence || "/"
      path += "?#{request.query_string}" if request.query_string.present?
      "#{Configuration.base_url}#{path}"
    end
  end
end
