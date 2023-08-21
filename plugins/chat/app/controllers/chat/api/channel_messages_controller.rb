# frozen_string_literal: true

class Chat::Api::ChannelMessagesController < Chat::ApiController
  def index
    with_service(::Chat::ListChannelMessages) do
      on_success { render_serialized(result, ::Chat::MessagesSerializer, root: false) }
      on_failed_policy(:can_view_channel) { raise Discourse::InvalidAccess }
      on_failed_policy(:target_message_exists) { raise Discourse::NotFound }
      on_model_not_found(:channel) { raise Discourse::NotFound }
    end
  end

  def destroy
    with_service(Chat::TrashMessage) { on_model_not_found(:message) { raise Discourse::NotFound } }
  end

  def restore
    with_service(Chat::RestoreMessage) do
      on_model_not_found(:message) { raise Discourse::NotFound }
    end
  end
end
