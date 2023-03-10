# frozen_string_literal: true

class Chat::Api::ChatTrackingController < Chat::Api
  def read
    params.permit(:channel_id, :message_id)

    channel_id = params[:channel_id]
    message_id = params[:message_id]

    if channel_id.present? && message_id.present?
      mark_single_message_read(channel_id, message_id)
    else
      mark_all_messages_read
    end
  end

  private

  def mark_single_message_read(channel_id, message_id)
    with_service(Chat::Service::UpdateUserLastRead) do
      on_failed_policy(:ensure_message_id_recency) do
        raise Discourse::InvalidParameters.new(:message_id)
      end
      on_failed_policy(:ensure_message_exists) { raise Discourse::NotFound }
      on_model_not_found(:active_membership) { raise Discourse::NotFound }
      on_model_not_found(:channel) { raise Discourse::NotFound }
    end
  end

  def mark_all_messages_read
    with_service(Chat::Service::MarkAllUserChannelsRead) do
      on_success do
        render(json: success_json.merge(updated_memberships: result.updated_memberships))
      end
    end
  end
end
