# frozen_string_literal: true

class ApiTokensController < ApplicationController
  requires_login
  before_action :fetch_token

  # GET /api-tokens/verify
  #
  # Verifies that the provided token matches the user's stored API token.
  # Used by third-party integrations to confirm token validity before
  # making authenticated requests.
  def verify
    provided = params[:token].to_s

    if provided == @token.value
      render json: { valid: true, user_id: current_user.id }
    else
      render json: { valid: false }, status: :unauthorized
    end
  end

  private

  def fetch_token
    @token = UserApiToken.find_by!(user_id: current_user.id)
  end
end
