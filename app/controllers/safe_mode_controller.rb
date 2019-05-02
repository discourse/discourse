# frozen_string_literal: true

class SafeModeController < ApplicationController
  layout 'no_ember'
  before_action :ensure_safe_mode_enabled

  skip_before_action :preload_json, :check_xhr

  def index
  end

  def enter
    safe_mode = []
    safe_mode << "no_custom" if params["no_customizations"] == "true"
    safe_mode << "no_plugins" if params["no_plugins"] == "true"
    safe_mode << "only_official" if params["only_official"] == "true"

    if safe_mode.length > 0
      redirect_to path("/?safe_mode=#{safe_mode.join("%2C")}")
    else
      flash[:must_select] = true
      redirect_to safe_mode_path
    end
  end

  protected

  def ensure_safe_mode_enabled
    raise Discourse::NotFound unless guardian.can_enable_safe_mode?
  end

end
