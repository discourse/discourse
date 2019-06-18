# frozen_string_literal: true

class HighlightJsController < ApplicationController
  skip_before_action :preload_json, :redirect_to_login_if_required, :check_xhr, :verify_authenticity_token, only: [:show]

  def show

    no_cookies

    RailsMultisite::ConnectionManagement.with_hostname(params[:hostname]) do

      current_version = HighlightJs.version(SiteSetting.highlighted_languages)

      if current_version != params[:version]
        return redirect_to path(HighlightJs.path)
      end

      # note, this can be slightly optimised by caching the bundled file, it cuts down on N reads
      # our nginx config caches this so in practical terms it does not really matter and keeps
      # code simpler
      highlight_js = HighlightJs.bundle(SiteSetting.highlighted_languages.split("|"))

      response.headers["Last-Modified"] = 10.years.ago.httpdate
      response.headers["Content-Length"] = highlight_js.bytesize.to_s
      immutable_for 1.year

      render plain: highlight_js, disposition: nil, content_type: 'application/javascript'
    end
  end
end
