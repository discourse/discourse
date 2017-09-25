require_dependency 'upload_creator'

class Admin::ThemesController < Admin::AdminController

  skip_before_action :check_xhr, only: [:show, :preview]

  def preview
    @theme = Theme.find(params[:id])

    redirect_to path("/"), flash: { preview_theme_key: @theme.key }
  end

  def upload_asset
    path = params[:file].path
    File.open(path) do |file|
      filename = params[:file]&.original_filename || File.basename(path)
      upload = UploadCreator.new(file, filename, for_theme: true).create_for(current_user.id)
      if upload.errors.count > 0
        render_json_error upload
      else
        render json: { upload_id: upload.id }, status: :created
      end
    end
  end

  def import
    @theme = nil
    if params[:theme]
      json = JSON::parse(params[:theme].read)
      theme = json['theme']

      @theme = Theme.new(name: theme["name"], user_id: current_user.id)
      theme["theme_fields"]&.each do |field|
        @theme.set_field(target: field["target"], name: field["name"], value: field["value"])
      end

      if @theme.save
        log_theme_change(nil, @theme)
        render json: @theme, status: :created
      else
        render json: @theme.errors, status: :unprocessable_entity
      end
    elsif params[:remote]
      @theme = RemoteTheme.import_theme(params[:remote])
      render json: @theme, status: :created
    else
      render json: @theme.errors, status: :unprocessable_entity
    end
  end

  def index
    @theme = Theme.order(:name).includes(:theme_fields, :remote_theme)
    @color_schemes = ColorScheme.all.to_a
    light = ColorScheme.new(name: I18n.t("color_schemes.default"))
    @color_schemes.unshift(light)

    payload = {
      themes: ActiveModel::ArraySerializer.new(@theme, each_serializer: ThemeSerializer),
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
                       user_id: current_user.id,
                       user_selectable: theme_params[:user_selectable] || false,
                       color_scheme_id: theme_params[:color_scheme_id])
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
    @theme = Theme.find(params[:id])

    original_json = ThemeSerializer.new(@theme, root: false).to_json

    [:name, :color_scheme_id, :user_selectable].each do |field|
      if theme_params.key?(field)
        @theme.send("#{field}=", theme_params[field])
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

    save_remote = false
    if params[:theme][:remote_check]
      @theme.remote_theme.update_remote_version
      save_remote = true
    end

    if params[:theme][:remote_update]
      @theme.remote_theme.update_from_remote
      save_remote = true
    end

    respond_to do |format|
      if @theme.save

        @theme.remote_theme.save! if save_remote

        update_default_theme

        log_theme_change(original_json, @theme)
        format.json { render json: @theme, status: :created }
      else
        format.json {

          error = @theme.errors[:color_scheme] ? I18n.t("themes.bad_color_scheme") : I18n.t("themes.other_error")
          render json: { errors: [ error ] }, status: :unprocessable_entity
        }
      end
    end
  end

  def destroy
    @theme = Theme.find(params[:id])
    StaffActionLogger.new(current_user).log_theme_destroy(@theme)
    @theme.destroy

    respond_to do |format|
      format.json { head :no_content }
    end
  end

  def show
    @theme = Theme.find(params[:id])

    respond_to do |format|
      format.json do
        check_xhr
        render json: ThemeSerializer.new(@theme)
      end

      format.any(:html, :text) do
        raise RenderEmpty.new if request.xhr?

        response.headers['Content-Disposition'] = "attachment; filename=#{@theme.name.parameterize}.dcstyle.json"
        response.sending_file = true
        render json: ThemeSerializer.new(@theme)
      end
    end

  end

  private

    def update_default_theme
      if theme_params.key?(:default)
        is_default = theme_params[:default]

        if @theme.key == SiteSetting.default_theme_key && is_default == "false"
          Theme.clear_default!
        elsif is_default == "true"
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

    def log_theme_change(old_record, new_record)
      StaffActionLogger.new(current_user).log_theme_change(old_record, new_record)
    end

end
