class SvgSpriteController < ApplicationController
  skip_before_action :preload_json, :redirect_to_login_if_required, :check_xhr, :verify_authenticity_token, only: [:show]

  def show

    no_cookies

    RailsMultisite::ConnectionManagement.with_hostname(params[:hostname]) do

      if SvgSprite.version != params[:version]
        return redirect_to path(SvgSprite.path)
      end

      svg_sprite = SvgSprite.bundle

      response.headers["Last-Modified"] = 10.years.ago.httpdate
      response.headers["Content-Length"] = svg_sprite.bytesize.to_s
      immutable_for 1.year

      render plain: svg_sprite, disposition: nil, content_type: 'image/svg+xml'
    end
  end
end
