# frozen_string_literal: true

class Users::DiscourseIdController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:revoke]

  def revoke
    RateLimiter.new(nil, "discourse_id_revoke_#{params[:identifier]}", 5, 1.minute).performed!

    UserAuthToken::DestroyViaDiscourseId.call(
      params: {
        timestamp: params[:timestamp],
        signature: params[:signature],
        identifier: params[:identifier],
      },
    ) do
      on_success { render json: { success: true } }
      on_failure { render json: { error: "Invalid request" }, status: 400 }
    end
  end
end
