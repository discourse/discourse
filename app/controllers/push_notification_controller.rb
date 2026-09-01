# frozen_string_literal: true

class PushNotificationController < ApplicationController
  layout false
  before_action :ensure_logged_in
  before_action :ensure_current_push_user
  skip_before_action :preload_json

  def subscribe
    if PushNotificationPusher.subscribe(
         current_user,
         push_params,
         params[:send_confirmation],
         user_auth_token_id: request.env[Auth::DefaultCurrentUserProvider::USER_TOKEN_KEY]&.id,
       )
      render json: success_json
    else
      head :conflict
    end
  end

  def unsubscribe
    PushNotificationPusher.unsubscribe(current_user, push_params)
    render json: success_json
  end

  private

  def ensure_current_push_user
    return if params[:user_id].blank? || params[:user_id].to_s == current_user.id.to_s

    head :conflict
  end

  def push_params
    params.require(:subscription).permit(:endpoint, keys: %i[p256dh auth])
  end
end
