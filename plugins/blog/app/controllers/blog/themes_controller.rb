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
      # Liquid syntax isn't checked so the preview can show its diagnostics.
      working_copy = BlogTheme::AttributesContract.new(**theme_params)
      if working_copy.invalid?
        raise Discourse::InvalidParameters.new(working_copy.errors.full_messages.first)
      end
      token = ThemePreview.store_working_copy(working_copy.theme_attributes, user: current_user)
      render json: { url: ThemePreview.url(token, path:) }, status: :created
    end

    def index
      render json: {
               themes:
                 ActiveModel::ArraySerializer.new(
                   BlogTheme.all,
                   each_serializer: BlogThemeSerializer,
                 ).as_json,
               active: BlogTheme.active,
             }
    end

    def show
      render json: {
               theme: BlogThemeSerializer.new(BlogTheme.find(params[:id]), root: false).as_json,
               active: BlogTheme.active,
             }
    end

    def create
      BlogTheme::Create.call(service_params.deep_merge(params: theme_params)) do
        on_success do |theme:|
          render json: BlogThemeSerializer.new(theme, root: false).as_json, status: :created
        end
        on_failed_contract do |contract|
          raise Discourse::InvalidParameters.new(contract.errors.full_messages.first)
        end
        on_failed_policy(:can_manage_themes) { raise Discourse::InvalidAccess }
        on_failed_policy(:within_theme_limit) do |policy|
          raise Discourse::InvalidParameters.new(policy.reason)
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
      end
    end

    def update
      BlogTheme::Update.call(
        service_params.deep_merge(params: theme_params.merge(theme_id: params[:id])),
      ) do
        on_success do |revised_theme:|
          render json: BlogThemeSerializer.new(revised_theme, root: false).as_json
        end
        on_failed_contract do |contract|
          raise Discourse::InvalidParameters.new(contract.errors.full_messages.first)
        end
        on_failed_policy(:can_manage_themes) { raise Discourse::InvalidAccess }
        on_model_not_found(:theme) { raise Discourse::NotFound }
        on_failed_policy(:revision_is_current) do |policy|
          raise Discourse::InvalidParameters.new(policy.reason)
        end
      end
    end

    def destroy
      BlogTheme::Destroy.call(service_params.deep_merge(params: { theme_id: params[:id] })) do
        on_success { head :no_content }
        on_failed_contract do |contract|
          raise Discourse::InvalidParameters.new(contract.errors.full_messages.first)
        end
        on_failed_policy(:can_manage_themes) { raise Discourse::InvalidAccess }
        on_model_not_found(:theme) { raise Discourse::NotFound }
        on_failed_policy(:revision_is_current) do |policy|
          raise Discourse::InvalidParameters.new(policy.reason)
        end
        on_failed_policy(:theme_is_inactive) do
          raise Discourse::InvalidParameters.new(I18n.t("blog.themes.active_delete"))
        end
      end
    end

    def activate
      BlogTheme::Activate.call(service_params.deep_merge(params: { theme_id: params[:id] })) do
        on_success do |active_theme:|
          render json: BlogThemeSerializer.new(active_theme, root: false).as_json
        end
        on_failed_contract do |contract|
          raise Discourse::InvalidParameters.new(contract.errors.full_messages.first)
        end
        on_failed_policy(:can_manage_themes) { raise Discourse::InvalidAccess }
        on_model_not_found(:theme) { raise Discourse::NotFound }
        on_failed_policy(:revision_is_current) do |policy|
          raise Discourse::InvalidParameters.new(policy.reason)
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
      end
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
        return(render json: BlogThemeSerializer.new(theme, root: false).as_json, status: :created)
      end

      repository = params.require(:repository)
      branch = params[:branch]
      hijack do
        theme = ThemeImporter.import(repository: repository, branch: branch, user: current_user)
        render json: BlogThemeSerializer.new(theme, root: false).as_json, status: :created
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
        render json: BlogThemeSerializer.new(updated, root: false).as_json
      end
    end

    private

    def theme_params
      params.require(:theme).permit(*BlogTheme::FIELDS).to_h
    end

    def ensure_discussion_host
      raise Discourse::NotFound if Configuration.blog_host?(request)
    end
  end
end
