# frozen_string_literal: true

module Blog
  # Prepended from plugin.rb so these routes are matched before core's routes. Rails
  # draws prepended blocks before loading any routes file, so they can't live in
  # config/routes.rb.
  module Routes
    ON_BLOG_HOST = ->(request) do
      Configuration.blog_host?(request) && !Configuration.asset_path?(request.path)
    end
    ON_DEFAULT_BLOG_PATH = ->(request) do
      blog = Routes.blog_on_forum_path(request)
      blog&.is_default? && !Configuration.custom_domain?(blog)
    end
    ON_OTHER_BLOG_PATH = ->(request) do
      blog = Routes.blog_on_forum_path(request)
      blog.present? && !blog.is_default? && !Configuration.custom_domain?(blog)
    end
    MOVED_TO_CUSTOM_DOMAIN = ->(request) do
      blog = Routes.blog_on_forum_path(request)
      blog.present? && Configuration.custom_domain?(blog)
    end
    REVIEW_ON_FORUM = ->(_) do
      UpcomingChanges.enabled?(:blog_enabled) &&
        Instance.cached.any? { |blog| !Configuration.custom_domain?(blog) }
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
            constraints(REVIEW_ON_FORUM) do
              get "/review" => "review_reader#show"
              post "/review/feedback" => "review_reader#feedback"
            end

            # Drawn before the default blog's routes, whose article catch-all
            # would otherwise take these paths, including its redirect when the
            # default blog has moved to a custom domain.
            scope "/:blog_slug" do
              constraints(ON_OTHER_BLOG_PATH) { instance_exec(&ARTICLES) }
            end

            constraints(ON_DEFAULT_BLOG_PATH) { instance_exec(&ARTICLES) }

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

    private_constant :ON_BLOG_HOST,
                     :ON_DEFAULT_BLOG_PATH,
                     :ON_OTHER_BLOG_PATH,
                     :MOVED_TO_CUSTOM_DOMAIN,
                     :REVIEW_ON_FORUM,
                     :ARTICLES

    def self.blog_on_forum_path(request)
      return if !UpcomingChanges.enabled?(:blog_enabled)
      Configuration.blog_for_path(request.path_info)
    end

    def self.custom_domain_url(request)
      blog = Configuration.blog_for_path(request.path_info)
      path = request.path_info.delete_prefix(Configuration.path_prefix(blog)).presence || "/"
      path += "?#{request.query_string}" if request.query_string.present?
      "#{Configuration.base_url(blog)}#{path}"
    end
  end
end
