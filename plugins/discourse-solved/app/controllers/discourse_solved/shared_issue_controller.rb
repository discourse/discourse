# frozen_string_literal: true

class DiscourseSolved::SharedIssueController < ::ApplicationController
  requires_plugin DiscourseSolved::PLUGIN_NAME
  requires_login

  before_action :rate_limit_shared_issue

  def create
    DiscourseSolved::SharedIssue::Toggle.call(service_params) do
      on_success do |topic:, existing_shared_issue:|
        render json: {
                 count: DiscourseSolved::SharedIssue.count_for(topic),
                 user_created_shared_issue: existing_shared_issue.blank?,
               }
      end
      on_model_not_found(:topic) { raise Discourse::NotFound }
      on_failed_policy(:can_create_shared_issue) { raise Discourse::InvalidAccess }
      on_failed_contract do |contract|
        render json: failed_json.merge(errors: contract.errors.full_messages), status: :bad_request
      end
      on_failure { render json: failed_json, status: :unprocessable_entity }
    end
  end

  private

  def rate_limit_shared_issue
    return if current_user.staff? || params[:topic_id].blank?
    RateLimiter.new(
      nil,
      "shared-issue-#{current_user.id}-#{params[:topic_id]}",
      5,
      1.hour,
    ).performed!
  end
end
