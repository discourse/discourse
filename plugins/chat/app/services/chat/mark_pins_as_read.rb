# frozen_string_literal: true

module Chat
  class MarkPinsAsRead
    include Service::Base

    params do
      attribute :channel_id, :integer

      validates :channel_id, presence: true
    end

    model :channel
    model :membership
    policy :can_access_channel
    step :update_last_viewed_at

    private

    def fetch_channel(params:)
      Chat::Channel.find_by(id: params.channel_id)
    end

    def fetch_membership(guardian:, channel:)
      channel.membership_for(guardian.user)
    end

    def can_access_channel(guardian:, channel:)
      guardian.can_preview_chat_channel?(channel)
    end

    def update_last_viewed_at(membership:)
      membership.update!(last_viewed_pins_at: Time.zone.now)
    end
  end
end
