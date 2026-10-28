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
    rescue_from ActiveRecord::RecordNotFound, Discourse::NotFound do
      @page_title = I18n.t("blog.not_found_title")
      @description = I18n.t("blog.not_found_body")
      @canonical_url = "#{Configuration.origin}#{request.path}"
      response.headers["Cache-Control"] = "private, no-store"
      response.headers["X-Robots-Tag"] = "noindex"
      render "blog/articles/not_found", formats: [:html], status: :not_found
    end

    def index
      @page = [params[:page].to_i, 1].max
      @query = params[:q].to_s.strip.first(100)
      publications = Publication.publicly_visible
      if @query.present?
        term = "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%"
        publications =
          publications.where(
            "blog_revisions.data->>'title' ILIKE ? OR blog_revisions.data->>'excerpt' ILIKE ?",
            term,
            term,
          )
      end
      if params[:tag].present?
        tag = Tag.visible(Guardian.new).find_by!(slug: params[:tag])
        publications =
          publications.where(discussion_topic_id: TopicTag.where(tag_id: tag.id).select(:topic_id))
        @tag = tag
      end
      @archive = params[:archive].present?
      publications = publications.order(featured: :desc) unless @archive || @query.present? || @tag
      limit = SiteSetting.blog_posts_per_page
      selected =
        publications
          .newest
          .offset((@page - 1) * limit)
          .limit(limit + 1)
          .includes(:published_revision, discussion_topic: %i[first_post user image_upload tags])
          .to_a
      @more = selected.size > limit
      @publications = selected.first(limit)
      @page_title =
        @tag&.name ||
          (
            if @archive
              I18n.t("blog.archive")
            else
              SiteSetting.blog_title
            end
          )
      @description = SiteSetting.blog_description
      @canonical_url = "#{Configuration.origin}#{request.path}"
      @canonical_url += "?page=#{@page}" if @page > 1
      response.headers["X-Robots-Tag"] = "noindex" if @query.present?
    end

    def show
      stored_path = Path.find_by!(path: request.path)
      @publication =
        Publication
          .publicly_visible
          .includes(:published_revision, discussion_topic: %i[first_post user image_upload tags])
          .find(stored_path.publication_id)
      if @publication.path != request.path
        return(redirect_to(@publication.url, status: :moved_permanently, allow_other_host: true))
      end
      @topic = @publication.discussion_topic
      @article = @publication.article
      @page_title = @article.title
      @description = @publication.display_excerpt
      @canonical_url = @publication.url
    end

    def about
      @page_title = I18n.t("blog.about")
      @description = SiteSetting.blog_description
      @canonical_url = "#{Configuration.origin}/about"
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
          .newest
          .limit(50_000)
          .includes(:published_revision, discussion_topic: :first_post)
      render formats: [:xml], layout: false
    end

    def theme_css
      colors = <<~CSS
        :root {
          --blog-accent-color: ##{@blog_theme["accent_color"]};
          --blog-paper-color: ##{@blog_theme["paper_color"]};
          --blog-ink-color: ##{@blog_theme["ink_color"]};
        }
      CSS
      colors += @blog_theme["css"] unless params[:blog_safe_mode] == "1"
      response.headers["X-Robots-Tag"] = "noindex"
      render plain: colors, content_type: "text/css"
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
      render plain: "User-agent: *\nAllow: /\nSitemap: #{Configuration.origin}/sitemap.xml\n"
    end

    private

    def load_blog_theme
      if params[:blog_theme_preview].present?
        @blog_theme = BlogTheme.from_preview(params[:blog_theme_preview])
        @theme_preview_token = params[:blog_theme_preview]
        response.headers.delete("X-Frame-Options")
        policy =
          ContentSecurityPolicy.policy(base_url: Configuration.origin, path_info: request.path)
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
      unless Configuration.blog_host?(request) && Configuration.public_enabled?
        raise Discourse::NotFound
      end
      # Revoked visibility must take effect on the next request, including feeds and previews.
      response.headers["Cache-Control"] = "private, no-store"
    end
  end
end
