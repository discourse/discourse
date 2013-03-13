class Admin::SiteCustomizationsController < Admin::AdminController

  def index
    @site_customizations = SiteCustomization.all

    respond_to do |format|
      format.json { render json: @site_customizations }
    end
  end

  def create
    @site_customization = SiteCustomization.new(params[:site_customization])
    @site_customization.user_id = current_user.id

    respond_to do |format|
      if @site_customization.save
        format.json { render json: @site_customization, status: :created}
      else
        format.json { render json: @site_customization.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    @site_customization = SiteCustomization.find(params[:id])

    respond_to do |format|
      if @site_customization.update_attributes(params[:site_customization])
        format.json { head :no_content }
      else
        format.json { render json: @site_customization.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @site_customization = SiteCustomization.find(params[:id])
    @site_customization.destroy

    respond_to do |format|
      format.json { head :no_content }
    end
  end

end
