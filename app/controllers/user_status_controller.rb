# frozen_string_literal: true

class UserStatusController < ApplicationController
  requires_login

  def set
    ensure_feature_enabled
    description = params.require(:description)
    emoji = params.require(:emoji)

    current_user.set_status!(description, emoji)
    render json: success_json
  end

  def clear
    ensure_feature_enabled
    current_user.clear_status!
    render json: success_json
  end

  private

  def ensure_feature_enabled
    raise ActionController::RoutingError.new("Not Found") if !SiteSetting.enable_user_status
  end
end
