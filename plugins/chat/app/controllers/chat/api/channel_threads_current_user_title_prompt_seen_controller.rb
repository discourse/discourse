# frozen_string_literal: true

class Chat::Api::ChannelThreadsCurrentUserTitlePromptSeenController < Chat::ApiController
  def update
    Chat::MarkThreadTitlePromptSeen.call(service_params) do
      on_success do |membership:|
        render_serialized(membership, Chat::BaseThreadMembershipSerializer, root: "membership")
      end
      on_failure { render(json: failed_json, status: 422) }
      on_failed_policy(:threading_enabled_for_channel) { raise Discourse::NotFound }
      on_failed_policy(:can_view_channel) { raise Discourse::InvalidAccess }
      on_model_not_found(:thread) { raise Discourse::NotFound }
      on_failed_contract do |contract|
        render(json: failed_json.merge(errors: contract.errors.full_messages), status: 400)
      end
    end
  end
end
