# frozen_string_literal: true

class DiscourseSolved::MeTooController < ::ApplicationController
  requires_plugin DiscourseSolved::PLUGIN_NAME
  requires_login

  before_action :rate_limit_me_too

  def create
    DiscourseSolved::ToggleMeToo.call(service_params) do
      on_success do |topic:, existing_me_too:|
        render json: { count: topic.me_too_count, user_did_me_too: existing_me_too.blank? }
      end
      on_model_not_found(:topic) { raise Discourse::NotFound }
      on_failed_policy(:can_me_too) { raise Discourse::InvalidAccess }
      on_failed_contract do |contract|
        render json: failed_json.merge(errors: contract.errors.full_messages), status: :bad_request
      end
      on_failure { render json: failed_json, status: :unprocessable_entity }
    end
  end

  private

  def rate_limit_me_too
    return if current_user.staff? || params[:topic_id].blank?
    RateLimiter.new(nil, "me-too-#{current_user.id}-#{params[:topic_id]}", 5, 1.hour).performed!
  end
end
