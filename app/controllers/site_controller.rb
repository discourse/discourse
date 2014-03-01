require_dependency 'site_serializer'

class SiteController < ApplicationController

  def index
    @site = Site.new(guardian)
    render_serialized(@site, SiteSerializer)
  end

end
