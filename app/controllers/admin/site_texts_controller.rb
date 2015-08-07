class Admin::SiteTextsController < Admin::AdminController

  def show
    site_text = SiteText.find_or_new(params[:id].to_s)
    render_serialized(site_text, SiteTextSerializer, root: 'site_text')
  end

  def update
    site_text = SiteText.find_or_new(params[:id].to_s)

    # Updating to nothing is the same as removing it
    if params[:site_text][:value].present?
      site_text.value = params[:site_text][:value]
      site_text.save!
    else
      site_text.destroy
    end

    render_serialized(site_text, SiteTextSerializer, root: 'site_text')
  end
end
