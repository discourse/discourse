class Admin::SiteContentTypesController < Admin::AdminController

  def index
    render_serialized(SiteContent.content_types, SiteContentTypeSerializer)
  end

end
