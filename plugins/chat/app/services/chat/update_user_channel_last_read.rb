# frozen_string_literal: true

module Chat
  # Service responsible for updating the last read message id of a membership.
  #
  # @example
  #  Chat::UpdateUserChannelLastRead.call(params: { channel_id: 2, message_id: 3 }, guardian: guardian)
  #
  class UpdateUserChannelLastRead
    include ::Service::Base

    # @!method self.call(guardian:, params:)
    #   @param [Guardian] guardian
    #   @param [Hash] params
    #   @option params [Integer] :channel_id
    #   @option params [Integer] :message_id
    #   @return [Service::Base::Context]

    params do
      attribute :message_id, :integer
      attribute :channel_id, :integer

      validates :message_id, :channel_id, presence: true
    end
    model :channel
    model :membership
    policy :invalid_access
    model :message
    policy :ensure_message_id_recency
    transaction do
      step :update_membership_state
      step :mark_associated_mentions_as_read
    end
    step :publish_new_last_read_to_clients

    private

    def fetch_channel(params:)
      ::Chat::Channel.find_by(id: params.channel_id)
    end

    def fetch_membership(guardian:, channel:)
      ::Chat::ChannelMembershipManager.new(channel).find_for_user(guardian.user, following: true)
    end

    def invalid_access(guardian:, membership:)
      guardian.can_join_chat_channel?(membership.chat_channel)
    end

    def fetch_message(channel:, params:)
      ::Chat::Message.with_deleted.find_by(chat_channel_id: channel.id, id: params.message_id)
    end

    def ensure_message_id_recency(message:, membership:)
      !membership.last_read_message_id || message.id >= membership.last_read_message_id
    end

    def update_membership_state(message:, membership:)
      membership.update!(last_read_message_id: message.id, last_viewed_at: Time.zone.now)
    end

    def mark_associated_mentions_as_read(membership:, message:)
      ::Chat::Action::MarkMentionsRead.call(
        membership.user,
        channel_ids: [membership.chat_channel.id],
        message_id: message.id,
      )
    end

    def publish_new_last_read_to_clients(guardian:, channel:, message:)
      ::Chat::Publisher.publish_user_tracking_state!(guardian.user, channel, message)
    end
  end
end
