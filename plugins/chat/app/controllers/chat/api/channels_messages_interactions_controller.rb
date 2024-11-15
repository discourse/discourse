# frozen_string_literal: true

class Chat::Api::ChannelsMessagesInteractionsController < Chat::ApiController
  def create
    Chat::CreateMessageInteraction.call(service_params) do |result|
      on_success do
        render_serialized(
          result.interaction,
          Chat::MessageInteractionSerializer,
          root: "interaction",
        )
      end
      on_failure { render(json: failed_json, status: 422) }
      on_model_not_found(:message) { raise Discourse::NotFound }
      on_model_not_found(:action) { raise Discourse::NotFound }
      on_failed_contract do |contract|
        render(json: failed_json.merge(errors: contract.errors.full_messages), status: 400)
      end
    end
  end
end
