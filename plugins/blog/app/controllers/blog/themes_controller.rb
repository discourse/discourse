# frozen_string_literal: true

module ::Blog
  class ThemesController < ::Admin::AdminController
    helper Blog::BlogHelper
    requires_plugin PLUGIN_NAME
    skip_before_action :check_xhr, only: :export
    before_action :ensure_discussion_host

    rescue_from RemoteTheme::ImportError do |error|
      render_json_error error.message, status: :unprocessable_entity
    end

    def authoring
      publications =
        Publication
          .publicly_visible
          .newest
          .limit(30)
          .includes(:published_revision, discussion_topic: %i[first_post user image_upload tags])
      @publication =
        (
          if params[:article_id].present?
            publications.find(params[:article_id])
          else
            publications.first
          end
        )
      @publications = publications.first(10)
      @article = @publication&.article
      @topic = @publication&.discussion_topic
      @page = 1
      sample = view_context.blog_template_assigns
      sample["article"] ||= {
        "title" => I18n.t("blog.themes.sample_article"),
        "url" => "#{Configuration.base_url}/example",
        "excerpt" => I18n.t("blog.themes.sample_body"),
        "standfirst" => "",
        "author" => "",
        "published_at" => nil,
        "date" => "",
        "relative_date" => "",
        "reading_time" => "",
        "featured" => false,
        "image_url" => nil,
        "discussion_url" => Discourse.base_url,
        "replies" => 0,
        "replies_label" => "",
        "index" => "01",
        "updated_label" => nil,
        "body_html" => "<p>#{ERB::Util.html_escape(I18n.t("blog.themes.sample_body"))}</p>",
        "tags" => [],
      }
      render json: {
               templates:
                 TemplateRenderer::PAGES.to_h { |page|
                   ["template_#{page}", TemplateRenderer.builtin(page)]
                 },
               articles:
                 publications.map { |publication|
                   { id: publication.id, title: publication.article.title }
                 },
               variables: sample,
             }
    end

    def working_preview
      RateLimiter.new(current_user, "blog-theme-preview", 20, 1.minute).performed!
      path =
        case params[:page]
        when "index"
          "/"
        when "archive"
          "/archive"
        when "about"
          "/about"
        when "not_found"
          "/theme-preview-not-found-#{SecureRandom.hex(16)}"
        when "article"
          Publication.publicly_visible.find(params.require(:article_id)).path
        else
          raise Discourse::InvalidParameters.new(:page)
        end
      token = BlogTheme.working_preview(theme_params, user: current_user)
      render json: {
               url: "#{Configuration.base_url}#{path}?#{{ blog_theme_preview: token }.to_query}",
             },
             status: :created
    end

    def index
      render json: {
               themes: BlogTheme.all.map { |theme| present(theme) },
               active: BlogTheme.active,
             }
    end

    def show
      render json: { theme: present(BlogTheme.find(params[:id])), active: BlogTheme.active }
    end

    def create
      theme = BlogTheme.save(theme_params, user: current_user)
      render json: present(theme), status: :created
    end

    def update
      theme =
        BlogTheme.save(
          theme_params,
          id: params[:id],
          revision: params.require(:revision),
          user: current_user,
        )
      render json: present(theme)
    end

    def destroy
      BlogTheme.destroy(params[:id], revision: params.require(:revision), user: current_user)
      head :no_content
    end

    def activate
      theme =
        BlogTheme.activate(params[:id], revision: params.require(:revision), user: current_user)
      render json: present(theme)
    end

    def export
      theme = BlogTheme.find(params[:id])
      send_data ThemeExporter.export(theme),
                filename: "blog-theme-#{theme["name"].parameterize.presence || "export"}.zip",
                type: "application/zip"
    end

    def import
      if params[:file]
        theme = ThemeImporter.import_file(file: params[:file], user: current_user)
        return render json: present(theme), status: :created
      end

      repository = params.require(:repository)
      branch = params[:branch]
      hijack do
        theme = ThemeImporter.import(repository: repository, branch: branch, user: current_user)
        render json: present(theme), status: :created
      end
    end

    def pull
      theme = BlogTheme.find(params[:id])
      source = theme["source"]
      raise Discourse::InvalidParameters.new(:source) unless source
      revision = params.require(:revision)
      hijack do
        updated =
          ThemeImporter.import(
            repository: source["repository"],
            branch: source["branch"],
            user: current_user,
            id: theme["id"],
            revision: revision,
          )
        render json: present(updated)
      end
    end

    private

    def present(theme)
      token = BlogTheme.preview_token(theme)
      theme.merge(
        "preview_url" => "#{Configuration.base_url}/?#{{ blog_theme_preview: token }.to_query}",
      )
    end

    def theme_params
      params.require(:theme).permit(*BlogTheme::FIELDS).to_h
    end

    def ensure_discussion_host
      raise Discourse::NotFound if Configuration.blog_host?(request)
    end
  end
end
