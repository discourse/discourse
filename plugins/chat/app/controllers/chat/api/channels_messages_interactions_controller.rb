# frozen_string_literal: true

class Chat::Api::ChannelsMessagesInteractionsController < Chat::ApiController
  def create
    Chat::CreateMessageInteraction.call(service_params) do
      on_success do |interaction:|
        render_serialized(interaction, Chat::MessageInteractionSerializer, root: "interaction")
      end
      on_failure { render(json: failed_json, status: :unprocessable_entity) }
      on_model_not_found(:message) { raise Discourse::NotFound }
      on_model_not_found(:action) { raise Discourse::NotFound }
      on_failed_contract do |contract|
        render(json: failed_json.merge(errors: contract.errors.full_messages), status: :bad_request)
      end
    end
  end
end
