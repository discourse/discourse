class SiteCustomizationsController < ApplicationController
  skip_before_filter :preload_json, :check_xhr, :redirect_to_login_if_required

  def show
    no_cookies

    cache_time = request.env["HTTP_IF_MODIFIED_SINCE"]
    cache_time = Time.rfc2822(cache_time) rescue nil if cache_time
    stylesheet_time =
      begin
        if params[:key].to_s == SiteCustomization::ENABLED_KEY
          SiteCustomization.where(enabled: true)
              .order('created_at desc')
              .limit(1)
              .pluck(:created_at)
              .first
        else
          SiteCustomization.where(key: params[:key].to_s).pluck(:created_at).first
        end
      end

    if !stylesheet_time
      raise Discourse::NotFound
    end

    if cache_time && stylesheet_time <= cache_time
      return render nothing: true, status: 304
    end

    response.headers["Last-Modified"] = stylesheet_time.httpdate
    expires_in 1.year, public: true
    render text: SiteCustomization.stylesheet_contents(params[:key], params[:target]),
           content_type: "text/css"
  end
end
