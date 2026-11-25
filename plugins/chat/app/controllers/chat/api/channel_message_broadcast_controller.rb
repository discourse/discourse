# frozen_string_literal: true

class Chat::Api::ChannelMessageBroadcastController < Chat::ApiController
  def create
    update_broadcast(true)
  end

  def destroy
    update_broadcast(false)
  end

  private

  def update_broadcast(value)
    Chat::UpdateMessageBroadcast.call(service_params.deep_merge(params: { broadcast: value })) do
      on_success { render json: success_json }
      on_failure { render json: failed_json, status: :unprocessable_entity }
      on_model_not_found(:channel) { raise Discourse::NotFound }
      on_model_not_found(:message) { raise Discourse::NotFound }
      on_failed_policy(:can_manage_broadcast) { raise Discourse::InvalidAccess }
      on_failed_policy(:broadcastable_message) do
        render_json_error(I18n.t("chat.errors.broadcast_not_allowed"))
      end
      on_failed_contract do |contract|
        render(json: failed_json.merge(errors: contract.errors.full_messages), status: :bad_request)
      end
    end
  end
end
