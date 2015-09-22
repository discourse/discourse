class Admin::SiteCustomizationsController < Admin::AdminController

  before_filter :enable_customization

  skip_before_filter :check_xhr, only: [:show]

  def index
    @site_customizations = SiteCustomization.order(:name)

    respond_to do |format|
      format.json { render json: @site_customizations }
    end
  end

  def create
    @site_customization = SiteCustomization.new(site_customization_params)
    @site_customization.user_id = current_user.id

    respond_to do |format|
      if @site_customization.save
        log_site_customization_change(nil, site_customization_params)
        format.json { render json: @site_customization, status: :created}
      else
        format.json { render json: @site_customization.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    @site_customization = SiteCustomization.find(params[:id])
    log_record = log_site_customization_change(@site_customization, site_customization_params)

    respond_to do |format|
      if @site_customization.update_attributes(site_customization_params)
        format.json { render json: @site_customization, status: :created}
      else
        log_record.destroy if log_record
        format.json { render json: @site_customization.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @site_customization = SiteCustomization.find(params[:id])
    StaffActionLogger.new(current_user).log_site_customization_destroy(@site_customization)
    @site_customization.destroy

    respond_to do |format|
      format.json { head :no_content }
    end
  end

  def show
    @site_customization = SiteCustomization.find(params[:id])

    respond_to do |format|
      format.json do
        check_xhr
        render json: SiteCustomizationSerializer.new(@site_customization)
      end

      format.any(:html, :text) do
        raise RenderEmpty.new if request.xhr?

        response.headers['Content-Disposition'] = "attachment; filename=#{@site_customization.name.parameterize}.dcstyle.json"
        response.sending_file = true
        render json: SiteCustomizationSerializer.new(@site_customization)
      end
    end

  end

  private

    def site_customization_params
      params.require(:site_customization)
            .permit(:name, :stylesheet, :header, :top, :footer,
                    :mobile_stylesheet, :mobile_header, :mobile_top, :mobile_footer,
                    :head_tag, :body_tag,
                    :position, :enabled, :key,
                    :stylesheet_baked, :embedded_css)
    end

    def log_site_customization_change(old_record, new_params)
      StaffActionLogger.new(current_user).log_site_customization_change(old_record, new_params)
    end

    def enable_customization
      session[:disable_customization] = false
    end

end
