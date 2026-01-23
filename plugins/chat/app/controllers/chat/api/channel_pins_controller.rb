# frozen_string_literal: true

class Chat::Api::ChannelPinsController < Chat::ApiController
  def index
    raise Discourse::NotFound unless SiteSetting.chat_pinned_messages

    Chat::ListChannelPins.call(service_params) do
      on_success do |pins:, membership:|
        render json: {
                 pinned_messages:
                   ActiveModel::ArraySerializer.new(
                     pins,
                     each_serializer: Chat::PinnedMessageSerializer,
                     scope: guardian,
                   ),
                 membership:
                   Chat::UserChannelMembershipSerializer.new(
                     membership,
                     scope: guardian,
                     root: false,
                   ),
               }
      end
      on_model_not_found(:channel) { raise Discourse::NotFound }
      on_model_not_found(:membership) do |pins:|
        render json: {
                 pinned_messages:
                   ActiveModel::ArraySerializer.new(
                     pins,
                     each_serializer: Chat::PinnedMessageSerializer,
                     scope: guardian,
                   ),
                 membership: nil,
               }
      end
      on_failed_policy(:can_view_channel) { raise Discourse::InvalidAccess }
      on_failed_contract do |contract|
        render(json: failed_json.merge(errors: contract.errors.full_messages), status: :bad_request)
      end
      on_failure { render(json: failed_json, status: :unprocessable_entity) }
    end
  end

  def mark_read
    raise Discourse::NotFound unless SiteSetting.chat_pinned_messages

    Chat::MarkPinsAsRead.call(params: { channel_id: params[:channel_id] }, guardian: guardian) do
      on_success { render json: success_json }
      on_model_not_found(:channel) { raise Discourse::NotFound }
      on_model_not_found(:membership) { raise Discourse::NotFound }
      on_failed_policy(:can_access_channel) { raise Discourse::InvalidAccess }
      on_failed_contract do |contract|
        render(json: failed_json.merge(errors: contract.errors.full_messages), status: :bad_request)
      end
      on_failure { render(json: failed_json, status: :unprocessable_entity) }
    end
  end

  def create
    raise Discourse::NotFound unless SiteSetting.chat_pinned_messages

    Chat::PinMessage.call(service_params) do
      on_success { render(json: success_json) }
      on_failure { render(json: failed_json, status: :unprocessable_entity) }
      on_model_not_found(:message) { raise Discourse::NotFound }
      on_failed_policy(:can_pin) { raise Discourse::InvalidAccess }
      on_failed_policy(:within_pin_limit) do
        render(
          json:
            failed_json.merge(
              error:
                I18n.t(
                  "chat.errors.pin_limit_reached",
                  limit: Chat::PinnedMessage::MAX_PINS_PER_CHANNEL,
                ),
            ),
          status: :unprocessable_entity,
        )
      end
      on_failed_policy(:not_already_pinned) do
        render(
          json: failed_json.merge(error: I18n.t("chat.errors.message_already_pinned")),
          status: :unprocessable_entity,
        )
      end
      on_failed_contract do |contract|
        render(json: failed_json.merge(errors: contract.errors.full_messages), status: :bad_request)
      end
    end
  end

  def destroy
    raise Discourse::NotFound unless SiteSetting.chat_pinned_messages

    Chat::UnpinMessage.call(service_params) do
      on_success { render(json: success_json) }
      on_failure { render(json: failed_json, status: :unprocessable_entity) }
      on_model_not_found(:message) { raise Discourse::NotFound }
      on_model_not_found(:pin) do
        render(
          json: failed_json.merge(error: I18n.t("chat.errors.message_not_pinned")),
          status: :unprocessable_entity,
        )
      end
      on_failed_policy(:can_unpin) { raise Discourse::InvalidAccess }
      on_failed_contract do |contract|
        render(json: failed_json.merge(errors: contract.errors.full_messages), status: :bad_request)
      end
    end
  end
end
