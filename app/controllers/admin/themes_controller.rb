# frozen_string_literal: true

require_dependency 'upload_creator'
require_dependency 'theme_store/tgz_exporter'
require 'base64'

class Admin::ThemesController < Admin::AdminController

  skip_before_action :check_xhr, only: [:show, :preview, :export]

  def preview
    theme = Theme.find_by(id: params[:id])
    raise Discourse::InvalidParameters.new(:id) unless theme

    redirect_to path("/?preview_theme_id=#{theme.id}")
  end

  def upload_asset
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
    require 'sshkey'
    k = SSHKey.generate

    render json: {
      private_key: k.private_key,
      public_key: k.ssh_public_key
    }
  end

  def import
    @theme = nil
    if params[:theme] && params[:theme].content_type == "application/json"
      # .dcstyle.json import. Deprecated, but still available to allow conversion
      json = JSON::parse(params[:theme].read)
      theme = json['theme']

      @theme = Theme.new(name: theme["name"], user_id: theme_user.id)
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
          upload_id: field["upload_id"]
        )
      end

      if @theme.save
        log_theme_change(nil, @theme)
        render json: @theme, status: :created
      else
        render json: @theme.errors, status: :unprocessable_entity
      end
    elsif params[:remote]
      begin
        branch = params[:branch] ? params[:branch] : nil
        @theme = RemoteTheme.import_theme(params[:remote], theme_user, private_key: params[:private_key], branch: branch)
        render json: @theme, status: :created
      rescue RemoteTheme::ImportError => e
        render_json_error e.message
      end
    elsif params[:bundle] || (params[:theme] && ["application/x-gzip", "application/gzip", "application/zip"].include?(params[:theme].content_type))
      # params[:bundle] used by theme CLI. params[:theme] used by admin UI
      bundle = params[:bundle] || params[:theme]
      theme_id = params[:theme_id]
      match_theme_by_name = !!params[:bundle] && !params.key?(:theme_id) # Old theme CLI behavior, match by name. Remove Jan 2020
      begin
        @theme = RemoteTheme.update_tgz_theme(bundle.path, match_theme: match_theme_by_name, user: theme_user, theme_id: theme_id)
        log_theme_change(nil, @theme)
        render json: @theme, status: :created
      rescue RemoteTheme::ImportError => e
        render_json_error e.message
      end
    else
      render_json_error I18n.t("themes.import_error.unknown_file_type"), status: :unprocessable_entity
    end
  end

  def index
    @themes = Theme.order(:name).includes(:child_themes,
                                          :parent_themes,
                                          :remote_theme,
                                          :theme_settings,
                                          :settings_field,
                                          :locale_fields,
                                          :user,
                                          :color_scheme,
                                          theme_fields: :upload
                                          )
    @color_schemes = ColorScheme.all.includes(:theme, color_scheme_colors: :color_scheme).to_a
    light = ColorScheme.new(name: I18n.t("color_schemes.light"))
    @color_schemes.unshift(light)

    payload = {
      themes: ActiveModel::ArraySerializer.new(@themes, each_serializer: ThemeSerializer),
      extras: {
        color_schemes: ActiveModel::ArraySerializer.new(@color_schemes, each_serializer: ColorSchemeSerializer)
      }
    }

    respond_to do |format|
      format.json { render json: payload }
    end
  end

  def create
    @theme = Theme.new(name: theme_params[:name],
                       user_id: theme_user.id,
                       user_selectable: theme_params[:user_selectable] || false,
                       color_scheme_id: theme_params[:color_scheme_id],
                       component: [true, "true"].include?(theme_params[:component]))
    set_fields

    respond_to do |format|
      if @theme.save
        update_default_theme
        log_theme_change(nil, @theme)
        format.json { render json: @theme, status: :created }
      else
        format.json { render json: @theme.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    @theme = Theme.find_by(id: params[:id])
    raise Discourse::InvalidParameters.new(:id) unless @theme

    original_json = ThemeSerializer.new(@theme, root: false).to_json
    disables_component = [false, "false"].include?(theme_params[:enabled])
    enables_component = [true, "true"].include?(theme_params[:enabled])

    [:name, :color_scheme_id, :user_selectable, :enabled].each do |field|
      if theme_params.key?(field)
        @theme.public_send("#{field}=", theme_params[field])
      end
    end

    if theme_params.key?(:child_theme_ids)
      expected = theme_params[:child_theme_ids].map(&:to_i)

      @theme.child_theme_relation.to_a.each do |child|
        if expected.include?(child.child_theme_id)
          expected.reject! { |id| id == child.child_theme_id }
        else
          child.destroy
        end
      end

      Theme.where(id: expected).each do |theme|
        @theme.add_child_theme!(theme)
      end
    end

    set_fields
    update_settings
    update_translations
    handle_switch

    if params[:theme][:remote_check]
      @theme.remote_theme.update_remote_version
    end

    if params[:theme][:remote_update]
      @theme.remote_theme.update_from_remote
    end

    respond_to do |format|
      if @theme.save
        update_default_theme

        @theme.reload

        if (!disables_component && !enables_component) || theme_params.keys.size > 1
          log_theme_change(original_json, @theme)
        end
        log_theme_component_disabled if disables_component
        log_theme_component_enabled if enables_component

        format.json { render json: @theme, status: :ok }
      else
        format.json do
          error = @theme.errors.full_messages.join(", ").presence
          error = I18n.t("themes.bad_color_scheme") if @theme.errors[:color_scheme].present?
          error ||= I18n.t("themes.other_error")

          render json: { errors: [ error ] }, status: :unprocessable_entity
        end
      end
    end
  rescue RemoteTheme::ImportError => e
    render_json_error e.message
  end

  def destroy
    @theme = Theme.find_by(id: params[:id])
    raise Discourse::InvalidParameters.new(:id) unless @theme

    StaffActionLogger.new(current_user).log_theme_destroy(@theme)
    @theme.destroy

    respond_to do |format|
      format.json { head :no_content }
    end
  end

  def show
    @theme = Theme.find_by(id: params[:id])
    raise Discourse::InvalidParameters.new(:id) unless @theme

    render json: ThemeSerializer.new(@theme)
  end

  def export
    @theme = Theme.find_by(id: params[:id])
    raise Discourse::InvalidParameters.new(:id) unless @theme

    exporter = ThemeStore::TgzExporter.new(@theme)
    file_path = exporter.package_filename

    headers['Content-Length'] = File.size(file_path).to_s
    send_data File.read(file_path),
      filename: File.basename(file_path),
      content_type: "application/x-gzip"
  ensure
    exporter.cleanup!
  end

  def diff_local_changes
    theme = Theme.find_by(id: params[:id])
    raise Discourse::InvalidParameters.new(:id) unless theme
    changes = theme.remote_theme&.diff_local_changes
    respond_to do |format|
      format.json { render json: changes || {} }
    end
  end

  def update_single_setting
    params.require("name")
    @theme = Theme.find_by(id: params[:id])
    raise Discourse::InvalidParameters.new(:id) unless @theme

    setting_name = params[:name].to_sym
    new_value = params[:value] || nil

    previous_value = @theme.included_settings[setting_name]
    @theme.update_setting(setting_name, new_value)
    @theme.save

    log_theme_setting_change(setting_name, previous_value, new_value)

    updated_setting = @theme.included_settings.select { |key, val| key == setting_name }
    render json: updated_setting, status: :ok
  end

  private

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

        params.require(:theme).permit(
          :name,
          :color_scheme_id,
          :default,
          :user_selectable,
          :component,
          :enabled,
          settings: {},
          translations: {},
          theme_fields: [:name, :target, :value, :upload_id, :type_id],
          child_theme_ids: []
        )
      end
  end

  def set_fields
    return unless fields = theme_params[:theme_fields]

    fields.each do |field|
      @theme.set_field(
        target: field[:target],
        name: field[:name],
        value: field[:value],
        type_id: field[:type_id],
        upload_id: field[:upload_id]
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

    target_translations.each_pair do |translation_key, new_value|
      @theme.update_translation(translation_key, new_value)
    end
  end

  def log_theme_change(old_record, new_record)
    StaffActionLogger.new(current_user).log_theme_change(old_record, new_record)
  end

  def log_theme_setting_change(setting_name, previous_value, new_value)
    StaffActionLogger.new(current_user).log_theme_setting_change(setting_name, previous_value, new_value, @theme)
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
      @theme.switch_to_theme!
    elsif param.to_s == "true" && !@theme.component?
      @theme.switch_to_component!
    end
  end

  # Overridden by theme-creator plugin
  def theme_user
    current_user
  end
end
