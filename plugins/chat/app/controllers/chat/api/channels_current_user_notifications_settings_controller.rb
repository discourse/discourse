# frozen_string_literal: true

class Chat::Api::ChannelsCurrentUserNotificationsSettingsController < Chat::Api::ChannelsController
  MEMBERSHIP_EDITABLE_PARAMS = %i[muted muted_until notification_level]

  def update
    settings_params =
      params.require(:notifications_settings).permit(MEMBERSHIP_EDITABLE_PARAMS).to_h

    if settings_params[:muted_until].present?
      settings_params[:muted_until] = parse_muted_until(settings_params[:muted_until])
    elsif settings_params.key?(:muted)
      # Muting without an end time mutes the channel until it is unmuted manually.
      settings_params[:muted_until] = nil
    end

    membership_from_params.update!(settings_params)
    render_serialized(
      membership_from_params,
      Chat::UserChannelMembershipSerializer,
      root: "membership",
    )
  end

  private

  def parse_muted_until(value)
    Time.zone.parse(value.to_s) || raise(Discourse::InvalidParameters.new(:muted_until))
  rescue ArgumentError
    raise Discourse::InvalidParameters.new(:muted_until)
  end
end
