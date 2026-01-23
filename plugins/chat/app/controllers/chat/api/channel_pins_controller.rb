# frozen_string_literal: true

class Chat::Api::ChannelPinsController < Chat::ApiController
  def index
    raise Discourse::NotFound unless SiteSetting.chat_pinned_messages

    channel = Chat::Channel.find(params[:channel_id])
    raise Discourse::InvalidAccess unless guardian.can_preview_chat_channel?(channel)

    pins = Chat::PinnedMessage.for_channel(channel).includes(chat_message: :user)
    membership = channel.membership_for(guardian.user)

    # Capture old timestamp before marking as read
    old_last_viewed_pins_at = membership.last_viewed_pins_at

    # Mark as read in database for persistence
    Chat::MarkPinsAsRead.call(params: { channel_id: channel.id }, guardian: guardian)

    # Reload membership to get updated has_unseen_pins
    membership.reload

    # Override last_viewed_pins_at with old value for serialization
    # This keeps indicators visible on frontend while viewing
    membership.last_viewed_pins_at = old_last_viewed_pins_at

    render json: {
             pinned_messages: serialize_pins(pins),
             membership:
               Chat::UserChannelMembershipSerializer.new(membership, scope: guardian, root: false),
           }
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

  private

  def serialize_pins(pins)
    pins.map do |pin|
      {
        id: pin.id,
        chat_message_id: pin.chat_message_id,
        pinned_at: pin.created_at,
        pinned_by_id: pin.pinned_by_id,
        message: Chat::MessageSerializer.new(pin.chat_message, scope: guardian, root: false),
      }
    end
  end
end
