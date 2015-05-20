class SiteCustomizationsController < ApplicationController
  skip_before_filter :preload_json, :check_xhr, :redirect_to_login_if_required

  def show
    expires_in 1.year, public: true
    render text: SiteCustomization.stylesheet_contents(params[:key], params[:target] == "mobile" ? :mobile : :desktop),
           content_type: "text/css"
  end
end
