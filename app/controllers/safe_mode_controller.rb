# frozen_string_literal: true

class SafeModeController < ApplicationController
  layout "no_ember"
  before_action :ensure_safe_mode_enabled
  before_action :force_safe_mode_for_route

  skip_before_action :check_xhr

  def index
  end

  def enter
    safe_mode = []

    safe_mode << "no_themes" if params["no_themes"] == "true"

    if params["no_plugins"] == "true"
      safe_mode << "no_plugins"
    elsif params["no_unofficial_plugins"] == "true"
      safe_mode << "no_unofficial_plugins"
    elsif params["deprecation_errors"] == "true"
      safe_mode << "deprecation_errors"
    end

    if safe_mode.length > 0
      redirect_to path("/?safe_mode=#{safe_mode.join(",")}")
    else
      flash[:must_select] = true
      redirect_to safe_mode_path
    end
  end

  protected

  def ensure_safe_mode_enabled
    raise Discourse::NotFound unless guardian.can_enable_safe_mode?
  end

  def force_safe_mode_for_route
    request.env[ApplicationController::NO_THEMES] = true
    request.env[ApplicationController::NO_PLUGINS] = true
  end
end
