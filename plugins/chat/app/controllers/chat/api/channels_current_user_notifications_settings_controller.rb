# frozen_string_literal: true

class Chat::Api::ChannelsCurrentUserNotificationsSettingsController < Chat::Api::ChannelsController
  MEMBERSHIP_EDITABLE_PARAMS = %i[muted notification_level]

  def update
    settings_params = params.require(:notifications_settings).permit(MEMBERSHIP_EDITABLE_PARAMS)
    membership_from_params.update!(settings_params.to_h)
    render_serialized(
      membership_from_params,
      Chat::UserChannelMembershipSerializer,
      root: "membership",
    )
  end
end
