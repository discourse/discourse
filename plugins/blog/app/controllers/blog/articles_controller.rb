# frozen_string_literal: true

module ::Blog
  class ArticlesController < ::ApplicationController
    helper Blog::BlogHelper
    requires_plugin PLUGIN_NAME
    skip_before_action :check_xhr, :preload_json
    # These assets contain public code, never session data.
    skip_before_action :verify_authenticity_token, only: %i[theme_js highlight_js]
    before_action :ensure_public_blog
    before_action :load_blog_theme, except: :highlight_js
    layout "blog"

    # NOTE: Overrides ApplicationController's global not-found handling, which
    # renders the Ember app; the blog serves its own not-found page instead.
    rescue_from ActiveRecord::RecordNotFound, Discourse::NotFound do
      @page_title = I18n.t("blog.not_found_title")
      @description = I18n.t("blog.not_found_body")
      @canonical_url = "#{Configuration.base_url}#{blog_path}"
      @template_variables = template_variables
      response.headers["Cache-Control"] = "private, no-store"
      response.headers["X-Robots-Tag"] = "noindex"
      render "blog/articles/not_found", formats: [:html], status: :not_found
    end

    def index
      Article::List.call(
        service_params.deep_merge(params: { query: params[:q], tag_slug: params[:tag] }),
      ) do
        on_success do |params:, tag:, listing:|
          @archive = params.archive
          @page_title = tag&.name || (@archive ? I18n.t("blog.archive") : SiteSetting.blog_title)
          @canonical_url = "#{Configuration.base_url}#{blog_path}"
          @canonical_url += "?page=#{params.page}" if params.page > 1
          @template_variables =
            template_variables(
              publications: listing[:publications],
              page: params.page,
              more: listing[:has_more],
              query: params.query,
              archive: @archive,
              tag:,
            )
          @description = @template_variables.description
          response.headers["X-Robots-Tag"] = "noindex" if params.query.present?
        end
        on_failure { redirect_to_permalink || raise(Discourse::NotFound) }
      end
    end

    def show
      Article::Find.call(service_params.deep_merge(params: { path: blog_path })) do
        on_success do |publication:|
          @topic = publication.discussion_topic
          @page_title = publication.article.title
          @description = publication.display_description
          @canonical_url = publication.canonical_article_url
          @article_metadata = ArticleMetadata.new(publication, description: @description)
          @template_variables =
            template_variables(
              article: ArticleVariables.new(publication, preview_token: @theme_preview_token),
            )
        end
        on_failed_policy(:requested_path_is_current) do |publication:|
          redirect_to(publication.url, status: :moved_permanently, allow_other_host: true)
        end
        on_failure { redirect_to_permalink || raise(Discourse::NotFound) }
      end
    end

    def about
      @page_title = I18n.t("blog.about")
      @description = SiteSetting.blog_description
      @canonical_url = "#{Configuration.base_url}/about"
      @template_variables = template_variables
    end

    def feed
      @publications =
        Publication
          .publicly_visible
          .newest
          .limit(30)
          .includes(:published_revision, discussion_topic: %i[first_post user])
      render formats: [:rss], layout: false
    end

    def sitemap
      @publications =
        Publication
          .publicly_visible
          .where(canonical_url: "")
          .newest
          .limit(50_000)
          .includes(:published_revision, discussion_topic: :first_post)
      render formats: [:xml], layout: false
    end

    def theme_css
      css = <<~CSS
        :root {
          --blog-accent-color: ##{@blog_theme["accent_color"]};
          --blog-paper-color: ##{@blog_theme["paper_color"]};
          --blog-ink-color: ##{@blog_theme["ink_color"]};
        }
        #{@blog_theme["css"] unless params[:blog_safe_mode] == "1"}
      CSS
      response.headers["X-Robots-Tag"] = "noindex"
      render plain: css, content_type: "text/css"
    end

    def highlight_js
      raise Discourse::NotFound unless params[:version] == SyntaxHighlighter.version

      no_cookies
      apply_cdn_headers
      immutable_for 1.year
      render plain: SyntaxHighlighter.source, content_type: "application/javascript"
    end

    def theme_js
      response.headers["X-Robots-Tag"] = "noindex"
      code = params[:blog_safe_mode] == "1" ? "" : @blog_theme["javascript"]
      render plain: code, content_type: "application/javascript"
    end

    def robots
      render plain: "User-agent: *\nAllow: /\nSitemap: #{Configuration.base_url}/sitemap.xml\n"
    end

    private

    # Lets a migration redirect old URLs that match no article or tag, like author pages.
    # Relative targets are community paths, so they resolve against the community host.
    def redirect_to_permalink
      permalink = Permalink.find_by_url(request.fullpath)
      return if !permalink || !guardian.can_see_permalink_target?(permalink)
      target = permalink.target_url
      return if target.blank?

      # The URL helper leaves a bare "/" relative, which would point at the blog's own root.
      target = target == "/" ? "#{Discourse.base_url}/" : UrlHelper.absolute_without_cdn(target)
      redirect_to(target, status: :moved_permanently, allow_other_host: true)
    end

    def blog_path
      @blog_path ||= Configuration.relative_path(request)
    end

    def template_variables(**variables)
      TemplateVariables.new(
        title: @page_title,
        preview_token: @theme_preview_token,
        path: blog_path,
        **variables,
      )
    end

    def load_blog_theme
      if params[:blog_theme_preview].present?
        @blog_theme = ThemePreview.theme_for(params[:blog_theme_preview])
        @theme_preview_token = params[:blog_theme_preview]
        response.headers.delete("X-Frame-Options")
        policy =
          ContentSecurityPolicy.policy(
            base_url: "#{request.base_url}#{Discourse.base_path}",
            path_info: request.path_info,
          )
        policy = policy.gsub(/frame-ancestors[^;]*(;|$)/, "")
        response.headers[
          "Content-Security-Policy"
        ] = "#{policy}; frame-ancestors #{Discourse.base_url_no_prefix}"
        response.headers["X-Robots-Tag"] = "noindex, nofollow"
        response.headers["Referrer-Policy"] = "no-referrer"
      elsif %w[theme_css theme_js].include?(action_name) && params[:blog_theme_snapshot].present?
        @blog_theme = BlogTheme.snapshot(params[:blog_theme_snapshot])
      else
        @blog_theme = BlogTheme.active
      end
    end

    def ensure_public_blog
      raise Discourse::NotFound unless Configuration.blog_request?(request)
      # Revoked visibility must take effect on the next request, including feeds and previews.
      response.headers["Cache-Control"] = "private, no-store"
    end
  end
end
