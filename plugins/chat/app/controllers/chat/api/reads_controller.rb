# frozen_string_literal: true

class Chat::Api::ReadsController < Chat::ApiController
  def update
    params.require(:channel_id)
    params.require(:message_id)

    with_service(Chat::UpdateUserLastRead) do
      on_failed_policy(:ensure_message_id_recency) do
        raise Discourse::InvalidParameters.new(:message_id)
      end
      on_failed_policy(:ensure_message_exists) { raise Discourse::NotFound }
      on_model_not_found(:active_membership) { raise Discourse::NotFound }
      on_model_not_found(:channel) { raise Discourse::NotFound }
    end
  end

  def update_all
    with_service(Chat::MarkAllUserChannelsRead) do
      on_success do
        render(json: success_json.merge(updated_memberships: result.updated_memberships))
      end
    end
  end
end
