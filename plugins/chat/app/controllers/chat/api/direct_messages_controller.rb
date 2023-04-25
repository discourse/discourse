# frozen_string_literal: true

# TODO (martin) Remove this endpoint when we move to do the channel creation
# when a message is first sent to avoid double-request round trips for DMs.
class Chat::Api::DirectMessagesController < Chat::ApiController
  def create
    with_service(Chat::CreateDirectMessageChannel) do
      on_success do
        render_serialized(
          result.channel,
          Chat::ChannelSerializer,
          root: "channel",
          membership: result.membership,
        )
      end
      on_model_not_found(:target_users) { raise ActiveRecord::RecordNotFound }
      on_failed_policy(:does_not_exceed_max_direct_message_users) do |policy|
        raise Discourse::InvalidParameters.new(:target_usernames, policy.reason)
      end
      on_failed_policy(:acting_user_not_disallowing_all_messages) do
        render_json_error(I18n.t("chat.errors.actor_disallowed_dms"))
      end
      on_failed_policy(:acting_user_can_message_all_target_users) do |policy|
        render_json_error(policy.reason)
      end
      on_failed_policy(:acting_user_not_preventing_messages_from_any_target_users) do |policy|
        render_json_error(policy.reason)
      end
      on_failed_policy(:acting_user_not_ignoring_any_target_users) do |policy|
        render_json_error(policy.reason)
      end
      on_failed_policy(:acting_user_not_muting_any_target_users) do |policy|
        render_json_error(policy.reason)
      end
      on_model_errors(:direct_message) do |model|
        render_json_error(model, type: :record_invalid, status: 422)
      end
      on_model_errors(:channel) do |model|
        render_json_error(model, type: :record_invalid, status: 422)
      end
    end
  end
end
