# frozen_string_literal: true

class PushNotificationController < ApplicationController
  layout false
  before_action :ensure_logged_in
  skip_before_action :preload_json

  def subscribe
    PushNotificationPusher.subscribe(
      current_user,
      push_params,
      params[:send_confirmation],
      user_auth_token_id: request.env[Auth::DefaultCurrentUserProvider::USER_TOKEN_KEY]&.id,
    )
    render json: success_json
  end

  def unsubscribe
    PushNotificationPusher.unsubscribe(current_user, push_params)
    render json: success_json
  end

  private

  def push_params
    params.require(:subscription).permit(:endpoint, keys: %i[p256dh auth])
  end
end
