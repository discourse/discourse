class Admin::SiteContentsController < Admin::AdminController

  def show
    site_content = SiteContent.find_or_new(params[:id].to_s)
    render_serialized(site_content, SiteContentSerializer)
  end

  def update
    site_content = SiteContent.find_or_new(params[:id].to_s)

    # Updating to nothing is the same as removing it
    if params[:content].present?
      site_content.content = params[:content]
      site_content.save!
    else
      site_content.destroy
    end

    render nothing: true
  end
end
