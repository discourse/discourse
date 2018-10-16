class SvgSpriteController < ApplicationController
  skip_before_action :preload_json, :redirect_to_login_if_required, :check_xhr, :verify_authenticity_token, only: [:show]

  def show

    no_cookies

    RailsMultisite::ConnectionManagement.with_hostname(params[:hostname]) do

      # current_version = HighlightJs.version(SiteSetting.highlighted_languages)

      # if current_version != params[:version]
      #   return redirect_to path(HighlightJs.path)
      # end

      # note, this can be slightly optimised by caching the bundled file, it cuts down on N reads
      # our nginx config caches this so in practical terms it does not really matter and keeps
      # code simpler
      svg_sprite = SvgSprite.bundle('surprise|sun')

      response.headers["Last-Modified"] = 10.years.ago.httpdate
      response.headers["Content-Length"] = svg_sprite.bytesize.to_s
      immutable_for 1.year

      render plain: svg_sprite, disposition: nil, content_type: 'image/svg+xml'
    end
  end
end
