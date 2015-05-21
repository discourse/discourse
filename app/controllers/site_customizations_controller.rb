class SiteCustomizationsController < ApplicationController
  skip_before_filter :preload_json, :check_xhr, :redirect_to_login_if_required

  def show
    version = params["v"]

    if version && version == request.headers['If-None-Match']
      return render nothing: true, status: 304
    end

    response.headers["ETag"] = version if version
    expires_in 1.year, public: true
    render text: SiteCustomization.stylesheet_contents(params[:key], params[:target] == "mobile" ? :mobile : :desktop),
           content_type: "text/css"
  end
end
