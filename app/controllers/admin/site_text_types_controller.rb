class Admin::SiteTextTypesController < Admin::AdminController

  def index
    render_serialized(SiteText.text_types, SiteTextTypeSerializer, root: 'site_text_types')
  end

end
