# frozen_string_literal: true

class SvgSpriteController < ApplicationController
  skip_before_action :preload_json, :redirect_to_login_if_required, :check_xhr, :verify_authenticity_token, only: [:show, :search]

  requires_login except: [:show]

  def show

    no_cookies

    RailsMultisite::ConnectionManagement.with_hostname(params[:hostname]) do

      if SvgSprite.version != params[:version]
        return redirect_to path(SvgSprite.path)
      end

      svg_sprite = "window.__svg_sprite = #{SvgSprite.bundle.inspect};"

      response.headers["Last-Modified"] = 10.years.ago.httpdate
      response.headers["Content-Length"] = svg_sprite.bytesize.to_s
      immutable_for 1.year

      render plain: svg_sprite, disposition: nil, content_type: 'application/javascript'
    end
  end

  def search
    keyword = params.require(:keyword)
    data = SvgSprite.search(keyword)

    if data.blank?
      render body: nil, status: 404
    else
      render plain: data.inspect, disposition: nil, content_type: 'text/plain'
    end
  end
end
