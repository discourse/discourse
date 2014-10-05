class Admin::SiteTextTypesController < Admin::AdminController

  def index
    render_serialized(SiteText.text_types, SiteTextTypeSerializer)
  end

end
