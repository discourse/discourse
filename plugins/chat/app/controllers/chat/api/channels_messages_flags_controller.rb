# frozen_string_literal: true

class Chat::Api::ChannelsMessagesFlagsController < Chat::ApiController
  def create
    RateLimiter.new(current_user, "flag_chat_message", 4, 1.minutes).performed!

    Chat::FlagMessage.call(service_params) do
      on_success { render(json: success_json) }
      on_failure { render(json: failed_json, status: 422) }
      on_model_not_found(:message) { raise Discourse::NotFound }
      on_failed_policy(:can_flag_message_in_channel) { raise Discourse::InvalidAccess }
      on_failed_contract do |contract|
        render(json: failed_json.merge(errors: contract.errors.full_messages), status: 400)
      end
    end
  end
end
