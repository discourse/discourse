class Admin::SiteTextController < Admin::AdminController

  def show
    site_text = SiteText.find_or_new(params[:id].to_s)
    render_serialized(site_text, SiteTextSerializer)
  end

  def update
    site_text = SiteText.find_or_new(params[:id].to_s)

    # Updating to nothing is the same as removing it
    if params[:value].present?
      site_text.value = params[:value]
      site_text.save!
    else
      site_text.destroy
    end

    render nothing: true
  end
end
