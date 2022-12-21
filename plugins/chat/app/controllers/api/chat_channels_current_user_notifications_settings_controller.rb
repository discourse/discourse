# frozen_string_literal: true

MEMBERSHIP_EDITABLE_PARAMS = %i[muted desktop_notification_level mobile_notification_level]

class Chat::Api::ChatChannelsCurrentUserNotificationsSettingsController < Chat::Api::ChatChannelsController
  def update
    settings_params = params.require(:notifications_settings).permit(MEMBERSHIP_EDITABLE_PARAMS)
    membership_from_params.update!(settings_params.to_h)
    render_serialized(
      membership_from_params,
      UserChatChannelMembershipSerializer,
      root: "membership",
    )
  end
end
