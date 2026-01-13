# frozen_string_literal: true

class DevModeController < ApplicationController
  layout "no_ember"
  skip_before_action :preload_json, :check_xhr

  before_action :ensure_developer

  def index
    response.headers["X-Robots-Tag"] = "noindex, nofollow"
  end

  def enter
    if params["enable_rack_mini_profiler"] == "true"
      cookies.encrypted[:_mp_auth] = {
        value: {
          user_id: current_user.id,
          issued_at: Time.now.to_i,
        },
        expires: MINI_PROFILER_AUTH_COOKIE_EXPIRES_IN.from_now,
        httponly: true,
        secure: SiteSetting.force_https,
        same_site: :strict,
      }
    end
    redirect_to path("/")
  end

  private

  def ensure_developer
    raise Discourse::NotFound unless guardian.is_developer?
  end
end
