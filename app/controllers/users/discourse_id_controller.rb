# frozen_string_literal: true

class Users::DiscourseIdController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:revoke]

  def revoke
    RateLimiter.new(nil, "discourse_id_revoke_#{params[:identifier]}", 5, 1.minute).performed!

    DiscourseId::Revoke.call(service_params) do |result|
      on_success { render json: { success: true } }
      on_failed_contract do |contract|
        logger.warn(result.inspect_steps) if SiteSetting.discourse_id_verbose_logging
        render json: { error: contract.errors.full_messages.join(", ") }, status: 400
      end
      on_failure do
        logger.warn(result.inspect_steps) if SiteSetting.discourse_id_verbose_logging
        render json: { error: "Invalid request" }, status: 400
      end
    end
  end
end
