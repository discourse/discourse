# frozen_string_literal: true

module DiscourseWorkflows
  class ChatConversationsController < ::ApplicationController
    requires_plugin DiscourseWorkflows::PLUGIN_NAME
    requires_login only: %i[create]

    skip_before_action :check_xhr, only: :show

    def show
      render html: "", layout: "application"
    end

    def create
      RateLimiter.new(current_user, "open_workflow_chat", 10, 5.minutes).performed!

      ChatConversation::Open.call(service_params) do
        on_success { |channel:| render json: { url: channel.relative_url }, status: :created }
        on_failed_contract do |contract|
          render(
            json: failed_json.merge(errors: contract.errors.full_messages),
            status: :bad_request,
          )
        end
        on_failed_policy(:can_chat) { raise Discourse::InvalidAccess }
        on_model_not_found(:trigger) { raise Discourse::NotFound }
        on_model_not_found(:bot) { raise Discourse::NotFound }
        on_model_not_found(:channel) { raise Discourse::InvalidAccess }
      end
    end
  end
end
