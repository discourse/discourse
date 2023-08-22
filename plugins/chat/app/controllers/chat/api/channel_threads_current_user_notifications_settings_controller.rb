# frozen_string_literal: true

class Chat::Api::ChannelThreadsCurrentUserNotificationsSettingsController < Chat::ApiController
  def update
    with_service(Chat::UpdateThreadNotificationSettings) do
      on_failed_policy(:threading_enabled_for_channel) { raise Discourse::NotFound }
      on_failed_policy(:can_view_channel) { raise Discourse::InvalidAccess }
      on_model_not_found(:thread) { raise Discourse::NotFound }
      on_success do
        render_serialized(
          result.membership,
          Chat::BaseThreadMembershipSerializer,
          root: "membership",
        )
      end
    end
  end
end
