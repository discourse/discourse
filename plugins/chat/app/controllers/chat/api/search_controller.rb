# frozen_string_literal: true

class Chat::Api::SearchController < Chat::ApiController
  def index
    Chat::SearchMessage.call(service_params) do |result|
      on_success do |messages:|
        render json: {
                 messages:
                   ActiveModel::ArraySerializer.new(
                     messages,
                     each_serializer: ::Chat::MessageSerializer,
                     root: false,
                     scope: guardian,
                     include_channel: true,
                   ).as_json,
               }
      end
      on_failure do
        p result
        render(json: failed_json, status: 422)
      end
      on_model_not_found(:channel) { raise Discourse::NotFound }
      on_failed_policy(:can_view_channel) { raise Discourse::InvalidAccess }
      on_failed_contract do |contract|
        render(json: failed_json.merge(errors: contract.errors.full_messages), status: 400)
      end
    end
  end
end
