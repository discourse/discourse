# frozen_string_literal: true

require "base64"

class Admin::ThemesController < Admin::AdminController
  MAX_REMOTE_LENGTH = 10_000

  skip_before_action :check_xhr, only: %i[show preview export]
  before_action :ensure_admin

  def preview
    theme = Theme.find_by(id: params[:id])
    raise Discourse::InvalidParameters.new(:id) unless theme

    redirect_to path("/?preview_theme_id=#{theme.id}")
  end

  def upload_asset
    ban_in_allowlist_mode!

    path = params[:file].path

    hijack do
      File.open(path) do |file|
        filename = params[:file]&.original_filename || File.basename(path)
        upload = UploadCreator.new(file, filename, for_theme: true).create_for(theme_user.id)
        if upload.errors.count > 0
          render_json_error upload
        else
          render json: { upload_id: upload.id }, status: :created
        end
      end
    end
  end

  def generate_key_pair
    require "sshkey"
    k = SSHKey.generate
    Discourse.redis.setex("ssh_key_#{k.ssh_public_key}", 1.hour, k.private_key)
    render json: { public_key: k.ssh_public_key }
  end

  THEME_CONTENT_TYPES = %w[
    application/gzip
    application/x-gzip
    application/x-zip-compressed
    application/zip
  ].freeze

  def import
    @theme = nil
    if params[:theme] && params[:theme].content_type == "application/json"
      ban_in_allowlist_mode!

      # .dcstyle.json import. Deprecated, but still available to allow conversion
      json = JSON.parse(params[:theme].read)
      theme = json["theme"]

      @theme = Theme.new(name: theme["name"], user_id: theme_user.id, auto_update: false)
      theme["theme_fields"]&.each do |field|
        if field["raw_upload"]
          begin
            tmp = Tempfile.new
            tmp.binmode
            file = Base64.decode64(field["raw_upload"])
            tmp.write(file)
            tmp.rewind
            upload = UploadCreator.new(tmp, field["filename"]).create_for(theme_user.id)
            field["upload_id"] = upload.id
          ensure
            tmp.unlink
          end
        end

        @theme.set_field(
          target: field["target"],
          name: field["name"],
          value: field["value"],
          type_id: field["type_id"],
          upload_id: field["upload_id"],
        )
      end

      if @theme.save
        log_theme_change(nil, @theme)
        render json: serialize_data(@theme, ThemeSerializer), status: :created
      else
        render json: @theme.errors, status: :unprocessable_entity
      end
    elsif remote = params[:remote]
      if remote.length > MAX_REMOTE_LENGTH
        error =
          I18n.t("themes.import_error.not_allowed_theme", { repo: remote[0..MAX_REMOTE_LENGTH] })
        return render_json_error(error, status: 422)
      end

      begin
        guardian.ensure_allowed_theme_repo_import!(remote.strip)
      rescue Discourse::InvalidAccess
        render_json_error I18n.t("themes.import_error.not_allowed_theme", { repo: remote.strip }),
                          status: :forbidden
        return
      end

      hijack do
        begin
          branch = params[:branch] ? params[:branch] : nil
          private_key =
            params[:public_key] ? Discourse.redis.get("ssh_key_#{params[:public_key]}") : nil
          if params[:public_key].present? && private_key.blank?
            return render_json_error I18n.t("themes.import_error.ssh_key_gone")
          end

          @theme =
            RemoteTheme.import_theme(remote, theme_user, private_key: private_key, branch: branch)
          render json: serialize_data(@theme, ThemeSerializer), status: :created
        rescue RemoteTheme::ImportError => e
          if params[:force]
            theme_name = params[:remote].gsub(/.git\z/, "").split("/").last

            remote_theme = RemoteTheme.new
            remote_theme.private_key = private_key
            remote_theme.branch = params[:branch] ? params[:branch] : nil
            remote_theme.remote_url = params[:remote]
            remote_theme.save!

            @theme = Theme.new(user_id: theme_user&.id || -1, name: theme_name)
            @theme.remote_theme = remote_theme
            @theme.save!

            render json: serialize_data(@theme, ThemeSerializer), status: :created
          else
            render_json_error e.message
          end
        end
      end
    elsif params[:bundle] ||
          (params[:theme] && THEME_CONTENT_TYPES.include?(params[:theme].content_type))
      ban_in_allowlist_mode!

      # params[:bundle] used by theme CLI. params[:theme] used by admin UI
      bundle = params[:bundle] || params[:theme]
      theme_id = params[:theme_id]
      update_components = params[:components]
      run_migrations = !params[:skip_migrations]

      begin
        @theme =
          RemoteTheme.update_zipped_theme(
            bundle.path,
            bundle.original_filename,
            user: theme_user,
            theme_id:,
            update_components:,
            run_migrations:,
          )

        log_theme_change(nil, @theme)
        render json: serialize_data(@theme, ThemeSerializer), status: :created
      rescue RemoteTheme::ImportError => e
        render_json_error e.message
      end
    else
      render_json_error I18n.t("themes.import_error.unknown_file_type"),
                        status: :unprocessable_entity
    end
  rescue Theme::SettingsMigrationError => err
    render_json_error err.message
  end

  def index
    @themes = Theme.include_relations.order(:name)
    @color_schemes = ColorScheme.all.includes(:theme, color_scheme_colors: :color_scheme).to_a

    payload = {
      themes: serialize_data(@themes, ThemeSerializer),
      extras: {
        color_schemes: serialize_data(@color_schemes, ColorSchemeSerializer),
        locale: current_user.effective_locale,
      },
    }

    respond_to { |format| format.json { render json: payload } }
  end

  def create
    ban_in_allowlist_mode!

    @theme =
      Theme.new(
        name: theme_params[:name],
        user_id: theme_user.id,
        user_selectable: theme_params[:user_selectable] || false,
        color_scheme_id: theme_params[:color_scheme_id],
        component: [true, "true"].include?(theme_params[:component]),
      )
    set_fields

    respond_to do |format|
      if @theme.save
        update_default_theme
        log_theme_change(nil, @theme)
        format.json { render json: serialize_data(@theme, ThemeSerializer), status: :created }
      else
        format.json { render json: @theme.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    @theme = Theme.include_relations.find_by(id: params[:id])
    raise Discourse::InvalidParameters.new(:id) unless @theme

    original_json = ThemeSerializer.new(@theme, root: false).to_json
    disables_component = [false, "false"].include?(theme_params[:enabled])
    enables_component = [true, "true"].include?(theme_params[:enabled])

    %i[name color_scheme_id user_selectable enabled auto_update].each do |field|
      @theme.public_send("#{field}=", theme_params[field]) if theme_params.key?(field)
    end

    @theme.child_theme_ids = theme_params[:child_theme_ids] if theme_params.key?(:child_theme_ids)

    @theme.parent_theme_ids = theme_params[:parent_theme_ids] if theme_params.key?(
      :parent_theme_ids,
    )

    set_fields
    update_settings
    update_translations
    handle_switch

    @theme.remote_theme.update_remote_version if params[:theme][:remote_check]

    if params[:theme][:remote_update]
      @theme.remote_theme.update_from_remote(raise_if_theme_save_fails: false)
    else
      @theme.save
    end

    respond_to do |format|
      if @theme.errors.blank?
        update_default_theme

        @theme = Theme.include_relations.find(@theme.id)

        if (!disables_component && !enables_component) || theme_params.keys.size > 1
          log_theme_change(original_json, @theme)
        end
        log_theme_component_disabled if disables_component
        log_theme_component_enabled if enables_component

        format.json { render json: serialize_data(@theme, ThemeSerializer), status: :ok }
      else
        format.json do
          error = @theme.errors.full_messages.join(", ").presence
          error = I18n.t("themes.bad_color_scheme") if @theme.errors[:color_scheme].present?
          error ||= I18n.t("themes.other_error")

          render json: { errors: [error] }, status: :unprocessable_entity
        end
      end
    end
  rescue RemoteTheme::ImportError => e
    render_json_error e.message
  rescue Theme::SettingsMigrationError => e
    render_json_error e.message
  end

  def destroy
    @theme = Theme.find_by(id: params[:id])
    raise Discourse::InvalidParameters.new(:id) unless @theme

    StaffActionLogger.new(current_user).log_theme_destroy(@theme)
    @theme.destroy

    respond_to { |format| format.json { head :no_content } }
  end

  def bulk_destroy
    themes = Theme.where(id: params[:theme_ids])
    raise Discourse::InvalidParameters.new(:id) if themes.blank?

    ActiveRecord::Base.transaction do
      themes.each { |theme| StaffActionLogger.new(current_user).log_theme_destroy(theme) }
      themes.destroy_all
    end

    respond_to { |format| format.json { head :no_content } }
  end

  def show
    @theme = Theme.include_relations.find_by(id: params[:id])
    raise Discourse::InvalidParameters.new(:id) unless @theme

    render_serialized(@theme, ThemeSerializer)
  end

  def export
    @theme = Theme.find_by(id: params[:id])
    raise Discourse::InvalidParameters.new(:id) unless @theme

    exporter = ThemeStore::ZipExporter.new(@theme)
    file_path = exporter.package_filename

    headers["Content-Length"] = File.size(file_path).to_s
    send_data File.read(file_path),
              filename: File.basename(file_path),
              content_type: "application/zip"
  ensure
    exporter.cleanup!
  end

  def get_translations
    params.require(:locale)
    if I18n.available_locales.exclude?(params[:locale].to_sym)
      raise Discourse::InvalidParameters.new(:locale)
    end

    I18n.locale = params[:locale]

    @theme = Theme.find_by(id: params[:id])
    raise Discourse::InvalidParameters.new(:id) unless @theme

    translations =
      @theme.translations.map do |translation|
        { key: translation.key, value: translation.value, default: translation.default }
      end

    render json: { translations: translations }, status: :ok
  end

  def update_single_setting
    params.require("name")
    @theme = Theme.find_by(id: params[:id])
    raise Discourse::InvalidParameters.new(:id) unless @theme

    setting_name = params[:name].to_sym
    new_value = params[:value] || nil

    previous_value = @theme.cached_settings[setting_name]

    begin
      @theme.update_setting(setting_name, new_value)
    rescue Discourse::InvalidParameters => e
      return render_json_error e.message
    end

    @theme.save

    log_theme_setting_change(setting_name, previous_value, new_value)

    updated_setting = @theme.cached_settings.select { |key, val| key == setting_name }
    render json: updated_setting, status: :ok
  end

  def schema
  end

  def objects_setting_metadata
    theme = Theme.find_by(id: params[:id])
    raise Discourse::InvalidParameters.new(:id) unless theme

    theme_setting = theme.settings[params[:setting_name].to_sym]
    raise Discourse::InvalidParameters.new(:setting_name) unless theme_setting

    render_serialized(theme_setting, ThemeObjectsSettingMetadataSerializer, root: false)
  end

  private

  def ban_in_allowlist_mode!
    raise Discourse::InvalidAccess if !Theme.allowed_remote_theme_ids.nil?
  end

  def ban_for_remote_theme!
    raise Discourse::InvalidAccess if @theme.remote_theme&.is_git?
  end

  def update_default_theme
    if theme_params.key?(:default)
      is_default = theme_params[:default].to_s == "true"
      if @theme.id == SiteSetting.default_theme_id && !is_default
        Theme.clear_default!
      elsif is_default
        @theme.set_default!
      end
    end
  end

  def theme_params
    @theme_params ||=
      begin
        # deep munge is a train wreck, work around it for now
        params[:theme][:child_theme_ids] ||= [] if params[:theme].key?(:child_theme_ids)
        params[:theme][:parent_theme_ids] ||= [] if params[:theme].key?(:parent_theme_ids)

        params.require(:theme).permit(
          :name,
          :color_scheme_id,
          :default,
          :user_selectable,
          :component,
          :enabled,
          :auto_update,
          :locale,
          settings: {
          },
          translations: {
          },
          theme_fields: %i[name target value upload_id type_id],
          child_theme_ids: [],
          parent_theme_ids: [],
        )
      end
  end

  def set_fields
    return unless fields = theme_params[:theme_fields]

    ban_in_allowlist_mode!
    ban_for_remote_theme!

    fields.each do |field|
      @theme.set_field(
        target: field[:target],
        name: field[:name],
        value: field[:value],
        type_id: field[:type_id],
        upload_id: field[:upload_id],
      )
    end
  end

  def update_settings
    return unless target_settings = theme_params[:settings]

    target_settings.each_pair do |setting_name, new_value|
      @theme.update_setting(setting_name.to_sym, new_value)
    end
  end

  def update_translations
    return unless target_translations = theme_params[:translations]

    locale = theme_params[:locale].presence
    if locale
      if I18n.available_locales.exclude?(locale.to_sym)
        raise Discourse::InvalidParameters.new(:locale)
      end
      I18n.locale = locale
    end

    target_translations.each_pair do |translation_key, new_value|
      @theme.update_translation(translation_key, new_value)
    end
  end

  def log_theme_change(old_record, new_record)
    StaffActionLogger.new(current_user).log_theme_change(old_record, new_record)
  end

  def log_theme_setting_change(setting_name, previous_value, new_value)
    StaffActionLogger.new(current_user).log_theme_setting_change(
      setting_name,
      previous_value,
      new_value,
      @theme,
    )
  end

  def log_theme_component_disabled
    StaffActionLogger.new(current_user).log_theme_component_disabled(@theme)
  end

  def log_theme_component_enabled
    StaffActionLogger.new(current_user).log_theme_component_enabled(@theme)
  end

  def handle_switch
    param = theme_params[:component]
    if param.to_s == "false" && @theme.component?
      if @theme.id == SiteSetting.default_theme_id
        raise Discourse::InvalidParameters.new(:component)
      end
      @theme.switch_to_theme!
    elsif param.to_s == "true" && !@theme.component?
      if @theme.id == SiteSetting.default_theme_id
        raise Discourse::InvalidParameters.new(:component)
      end
      @theme.switch_to_component!
    end
  end

  # Overridden by theme-creator plugin
  def theme_user
    current_user
  end
end
