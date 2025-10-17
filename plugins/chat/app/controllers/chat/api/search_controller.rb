# frozen_string_literal: true

class Chat::Api::SearchController < Chat::ApiController
  def index
    Chat::SearchMessage.call(service_params) do
      on_success do |messages:, has_more:|
        render json: {
                 messages:
                   ActiveModel::ArraySerializer.new(
                     messages,
                     each_serializer: ::Chat::MessageSerializer,
                     root: false,
                     scope: guardian,
                     include_channel: true,
                   ).as_json,
                 meta: {
                   has_more:,
                   limit: params.fetch(:limit, 20).to_i,
                   offset: params.fetch(:offset, 0).to_i,
                 },
               }
      end
      on_failure { render(json: failed_json, status: :unprocessable_entity) }
      on_model_not_found(:channel) { raise Discourse::NotFound }
      on_failed_policy(:can_view_channel) { raise Discourse::InvalidAccess }
      on_failed_contract do |contract|
        render(json: failed_json.merge(errors: contract.errors.full_messages), status: :bad_request)
      end
    end
  end
end
