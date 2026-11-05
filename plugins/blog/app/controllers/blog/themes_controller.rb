# frozen_string_literal: true

module ::Blog
  class ThemesController < ::Admin::AdminController
    # Matches the blog's own listing page, which the sample variables imitate.
    LISTING_SAMPLE_SIZE = 10
    WORKING_PREVIEWS_PER_MINUTE = 20

    requires_plugin PLUGIN_NAME
    skip_before_action :check_xhr, only: :export
    before_action :ensure_discussion_host
    before_action :rate_limit_working_preview, only: :working_preview

    def authoring
      BlogTheme::ListSampleArticles.call(service_params) do
        on_success do |publications:, publication:|
          variables =
            TemplateVariables.new(
              publications: publications.first(LISTING_SAMPLE_SIZE),
              article:
                publication ? ArticleVariables.new(publication) : ArticleVariables.placeholder,
            )
          render json:
                   ThemeAuthoringSerializer.new(
                     publications,
                     root: false,
                     variables: variables.to_h,
                   ).as_json
        end
        on_failed_contract do |contract|
          raise Discourse::InvalidParameters.new(contract.errors.full_messages.first)
        end
        on_failed_policy(:can_manage_themes) { raise Discourse::InvalidAccess }
        on_failed_policy(:requested_article_is_sample) { raise Discourse::NotFound }
      end
    end

    def working_preview
      BlogTheme::CreateWorkingPreview.call(service_params.deep_merge(params: theme_params)) do
        on_success do |preview_token:, preview_path:|
          render json: {
                   url: ThemePreview.url(preview_token, path: preview_path),
                 },
                 status: :created
        end
        on_failed_contract do |contract|
          raise Discourse::InvalidParameters.new(contract.errors.full_messages.first)
        end
        on_failed_policy(:can_manage_themes) { raise Discourse::InvalidAccess }
        on_model_not_found(:preview_path) { raise Discourse::NotFound }
      end
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
      params[:file] ? import_archive : import_repository
    end

    # Exceptions raised inside `hijack` surface as a 500, so the Git actions
    # render every outcome instead.
    def pull
      service_args = service_params.deep_merge(params: { theme_id: params[:id] })
      hijack do
        BlogTheme::Pull.call(service_args) do
          on_success do |pulled_theme:|
            render json: BlogThemeSerializer.new(pulled_theme, root: false).as_json
          end
          on_failed_contract do |contract|
            render_json_error contract.errors.full_messages.first, status: :bad_request
          end
          on_failed_policy(:can_manage_themes) do
            render_json_error I18n.t("invalid_access"), status: :forbidden
          end
          on_model_not_found(:theme) { render_json_error I18n.t("not_found"), status: :not_found }
          on_failed_policy(:imported_from_repository) do
            render_json_error I18n.t("invalid_params", message: "source"), status: :bad_request
          end
          on_failed_policy(:can_import_repository) do
            render_json_error I18n.t("invalid_access"), status: :forbidden
          end
          on_failed_policy(:revision_is_current) do |policy|
            render_json_error policy.reason, status: :bad_request
          end
          on_exceptions { |error| render_import_error(error) }
          on_failed_step(:revise_theme) do |step|
            render_json_error step.error, status: :bad_request
          end
        end
      end
    end

    private

    def import_archive
      BlogTheme::ImportArchive.call(service_params) do
        on_success do |theme:|
          render json: BlogThemeSerializer.new(theme, root: false).as_json, status: :created
        end
        on_failed_contract { raise Discourse::InvalidParameters.new(:file) }
        on_failed_policy(:can_manage_themes) { raise Discourse::InvalidAccess }
        on_exceptions { |error| raise Discourse::InvalidParameters.new(error.message) }
        on_failed_step(:create_theme) { |step| raise Discourse::InvalidParameters.new(step.error) }
      end
    end

    def import_repository
      service_args = service_params
      hijack do
        BlogTheme::ImportRepository.call(service_args) do
          on_success do |theme:|
            render json: BlogThemeSerializer.new(theme, root: false).as_json, status: :created
          end
          on_failed_contract do |contract|
            render_json_error contract.errors.full_messages.first, status: :bad_request
          end
          on_failed_policy(:can_manage_themes) do
            render_json_error I18n.t("invalid_access"), status: :forbidden
          end
          on_failed_policy(:can_import_repository) do
            render_json_error I18n.t("invalid_access"), status: :forbidden
          end
          on_exceptions { |error| render_import_error(error) }
          on_failed_step(:create_theme) do |step|
            render_json_error step.error, status: :bad_request
          end
        end
      end
    end

    def render_import_error(error)
      status = error.is_a?(RemoteTheme::ImportError) ? :unprocessable_entity : :bad_request
      render_json_error error.message, status:
    end

    def theme_params
      params.require(:theme).permit(*BlogTheme::FIELDS).to_h
    end

    def rate_limit_working_preview
      RateLimiter.new(
        current_user,
        "blog-theme-preview",
        WORKING_PREVIEWS_PER_MINUTE,
        1.minute,
      ).performed!
    end

    def ensure_discussion_host
      raise Discourse::NotFound if Configuration.blog_host?(request)
    end
  end
end
