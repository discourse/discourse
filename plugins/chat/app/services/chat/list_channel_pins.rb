# frozen_string_literal: true

module Chat
  class ListChannelPins
    include Service::Base

    params do
      attribute :channel_id, :integer

      validates :channel_id, presence: true
    end

    model :channel
    policy :can_view_channel
    model :membership, optional: true
    model :pins
    step :mark_pins_as_read
    step :restore_last_viewed_pins_at

    private

    def fetch_channel(params:)
      Chat::Channel.find_by(id: params.channel_id)
    end

    def can_view_channel(guardian:, channel:)
      guardian.can_preview_chat_channel?(channel)
    end

    def fetch_membership(channel:, guardian:)
      channel.membership_for(guardian.user)
    end

    def fetch_pins(channel:)
      user_includes =
        if SiteSetting.enable_user_status
          %i[user_status user_option primary_group]
        else
          %i[user_option primary_group]
        end

      Chat::PinnedMessage.for_channel(channel).includes(
        chat_message: [
          :revisions,
          :bookmarks,
          { uploads: { optimized_videos: :optimized_upload } },
          { chat_channel: :chatable },
          :thread,
          { user: user_includes },
          { user_mentions: { user: user_includes } },
          { reactions: :user },
          { in_reply_to: [:user] },
        ],
      )
    end

    def mark_pins_as_read(membership:)
      return if membership.blank?

      context[:old_last_viewed_pins_at] = membership.last_viewed_pins_at
      membership.update!(last_viewed_pins_at: Time.zone.now)
    end

    def restore_last_viewed_pins_at(membership:)
      return if membership.blank?

      membership.last_viewed_pins_at = context[:old_last_viewed_pins_at]
    end
  end
end
