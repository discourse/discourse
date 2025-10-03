# frozen_string_literal: true

class SvgSpriteController < ApplicationController
  skip_before_action :preload_json,
                     :redirect_to_login_if_required,
                     :redirect_to_profile_if_required,
                     :check_xhr,
                     :verify_authenticity_token,
                     only: %i[show search svg_icon]

  before_action :apply_cdn_headers, only: %i[show search svg_icon]

  requires_login except: %i[show svg_icon]

  def show
    no_cookies

    RailsMultisite::ConnectionManagement.with_hostname(params[:hostname]) do
      theme_id = params[:theme_id].to_i if params[:theme_id].present?

      if SvgSprite.version(theme_id) != params[:version]
        return redirect_to UrlHelper.absolute((SvgSprite.path(theme_id))), allow_other_host: true
      end

      svg_sprite = "window.__svg_sprite = #{SvgSprite.bundle(theme_id).inspect};"

      response.headers["Last-Modified"] = 10.years.ago.httpdate
      response.headers["Content-Length"] = svg_sprite.bytesize.to_s
      immutable_for 1.year

      render plain: svg_sprite, disposition: nil, content_type: "application/javascript"
    end
  end

  def search
    keyword = params.require(:keyword)
    data = SvgSprite.search(keyword)

    if data.blank?
      render body: nil, status: 404
    else
      render plain: data.inspect, disposition: nil, content_type: "text/plain"
    end
  end

  def icon_picker_search
    params.permit(:filter, :only_available)
    filter = params[:filter] || ""
    only_available = params[:only_available]

    icons = SvgSprite.icon_picker_search(filter, only_available).take(500)

    render json: icons, root: false
  end

  def svg_icon
    no_cookies

    RailsMultisite::ConnectionManagement.with_hostname(params[:hostname]) do
      params.permit(:color)
      name = params.require(:name)
      icon = SvgSprite.search(name)

      if icon.blank?
        render body: nil, status: 404
      else
        doc = Nokogiri.XML(icon)
        doc.at_xpath("symbol").name = "svg"
        doc.at_xpath("svg")["xmlns"] = "http://www.w3.org/2000/svg"
        doc.at_xpath("svg")["fill"] = adjust_hex(params[:color]) if params[:color]

        response.headers["Last-Modified"] = 1.years.ago.httpdate
        response.headers["Content-Length"] = doc.to_s.bytesize.to_s
        immutable_for 1.day

        render plain: doc, disposition: nil, content_type: "image/svg+xml"
      end
    end
  end

  private

  def adjust_hex(hex)
    if hex.size == 3
      chars = hex.scan(/\w/)
      hex = chars.zip(chars).flatten.join
    end
    "##{hex}"
  end
end
