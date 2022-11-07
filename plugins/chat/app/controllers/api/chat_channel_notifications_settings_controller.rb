# frozen_string_literal: true

MEMBERSHIP_EDITABLE_PARAMS = %i[muted desktop_notification_level mobile_notification_level]

class Chat::Api::ChatChannelNotificationsSettingsController < Chat::Api::ChatChannelsController
  def update
    settings_params = params.permit(MEMBERSHIP_EDITABLE_PARAMS)
    membership = find_membership
    membership.update!(settings_params.to_h)
    render_serialized(membership, UserChatChannelMembershipSerializer, root: false)
  end
end
