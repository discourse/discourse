# frozen_string_literal: true

class Chat::Api::ChannelsMessagesStreamingController < Chat::Api::ChannelsController
  def destroy
    with_service(Chat::StopMessageStreaming) do
      on_model_not_found(:message) { raise Discourse::NotFound }
      on_failed_policy(:can_join_channel) { raise Discourse::InvalidAccess }
      on_failed_policy(:can_stop_streaming) { raise Discourse::InvalidAccess }
    end
  end
end
