# frozen_string_literal: true

class Chat::Api::ChannelsMessagesFlagsController < Chat::ApiController
  def create
    RateLimiter.new(current_user, "flag_chat_message", 4, 1.minutes).performed!

    with_service(Chat::FlagMessage) do
      on_model_not_found(:message) { raise Discourse::NotFound }
      on_failed_policy(:can_flag_message_in_channel) { raise Discourse::InvalidAccess }
    end
  end
end
