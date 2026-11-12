# frozen_string_literal: true

class AnonymousActionsController < ApplicationController
  MAX_PARAMS_BYTES = 512

  def create
    raise Discourse::InvalidAccess if current_user

    RateLimiter.new(nil, "anonymous-action-min-#{request.remote_ip}", 10, 1.minute).performed!
    RateLimiter.new(nil, "anonymous-action-hr-#{request.remote_ip}", 60, 1.hour).performed!

    type = params.require(:type)
    raise Discourse::InvalidParameters.new(:type) if !AnonymousAction.registered?(type)

    raw_params = params[:params]
    action_params = raw_params.is_a?(ActionController::Parameters) ? raw_params.permit!.to_h : {}

    if action_params.to_json.bytesize > MAX_PARAMS_BYTES
      raise Discourse::InvalidParameters.new(:params)
    end

    AnonymousAction.set(cookies, type:, params: action_params)

    head :no_content
  end
end
