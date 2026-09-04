# frozen_string_literal: true

class PanelWindowsController < ApplicationController
  layout "panel_window"

  skip_before_action :preload_json, :check_xhr, :redirect_to_profile_if_required

  def show
    raise Discourse::NotFound unless params[:key]&.match?(/\A[a-zA-Z0-9][a-zA-Z0-9_\-]{0,63}\z/)

    @panel_key = params[:key]
    response.headers["X-Robots-Tag"] = "noindex, nofollow"
  end
end
