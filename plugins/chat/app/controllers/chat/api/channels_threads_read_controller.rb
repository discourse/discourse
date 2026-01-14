# frozen_string_literal: true

class Chat::Api::ChannelsThreadsReadController < Chat::ApiController
  def update
    Chat::UpdateUserThreadLastRead.call(service_params) do
      on_success { render(json: success_json) }
      on_failure { render(json: failed_json, status: :unprocessable_entity) }
      on_model_not_found(:thread) { raise Discourse::NotFound }
      on_model_not_found(:message) { raise Discourse::NotFound }
      on_failed_policy(:invalid_access) { raise Discourse::InvalidAccess }
      on_failed_contract do |contract|
        render(json: failed_json.merge(errors: contract.errors.full_messages), status: :bad_request)
      end
    end
  end
end
