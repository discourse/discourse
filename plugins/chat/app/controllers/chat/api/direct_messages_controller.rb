# frozen_string_literal: true

# TODO (martin) Remove this endpoint when we move to do the channel creation
# when a message is first sent to avoid double-request round trips for DMs.
class Chat::Api::DirectMessagesController < Chat::ApiController
  def create
    channel_params = params.require(:target_usernames)

    with_service(Chat::CreateDirectMessageChannel, **channel_params) do
      on_success do
        render_serialized(
          result.channel,
          Chat::ChannelSerializer,
          root: "channel",
          membership: result.membership,
        )
      end
      on_model_not_found(:target_users) { raise ActiveRecord::RecordNotFound }
      on_failed_policy(:does_not_exceed_max_direct_message_users) do
        error_message =
          if SiteSetting.chat_max_direct_message_users == 0
            I18n.t("chat.errors.over_chat_max_direct_message_users_allow_self")
          else
            I18n.t(
              "chat.errors.over_chat_max_direct_message_users",
              count: SiteSetting.chat_max_direct_message_users + 1, # +1 for the acting user
            )
          end

        raise Discourse::InvalidParameters.new(:target_usernames, error_message)
      end
      on_failed_policy(:acting_user_not_disallowing_all_messages) do
        render_json_error(I18n.t("chat.errors.actor_disallowed_dms"))
      end
      on_failed_policy(:acting_user_can_message_all_target_users) do
        render_json_error(
          I18n.t(
            "chat.errors.not_accepting_dms",
            username: result.preventing_communication_username,
          ),
        )
      end
      on_failed_policy(:acting_user_not_preventing_messages_from_any_target_users) do
        render_json_error(
          I18n.t(
            "chat.errors.actor_preventing_target_user_from_dm",
            username: result.preventing_communication_username,
          ),
        )
      end
      on_failed_policy(:acting_user_not_ignoring_any_target_users) do
        render_json_error(
          I18n.t(
            "chat.errors.actor_ignoring_target_user",
            username: result.preventing_communication_username,
          ),
        )
      end
      on_failed_policy(:acting_user_not_muting_any_target_users) do
        render_json_error(
          I18n.t(
            "chat.errors.actor_muting_target_user",
            username: result.preventing_communication_username,
          ),
        )
      end
      on_model_errors(:direct_message) do
        render_json_error(result.direct_message, type: :record_invalid, status: 422)
      end
      on_model_errors(:channel) do
        render_json_error(result.channel, type: :record_invalid, status: 422)
      end
    end
  end
end
