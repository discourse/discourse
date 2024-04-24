# frozen_string_literal: true

module Chat
  # Service responsible for marking messages in a thread
  # as read.
  #
  # @example
  #  Chat::UpdateUserThreadLastRead.call(channel_id: 2, thread_id: 3, message_id: 4, guardian: guardian)
  #
  class UpdateUserThreadLastRead
    include ::Service::Base

    # @!method call(channel_id:, thread_id:, guardian:)
    #   @param [Integer] channel_id
    #   @param [Integer] thread_id
    #   @param [Integer] message_id
    #   @param [Guardian] guardian
    #   @return [Service::Base::Context]

    contract
    model :thread
    policy :invalid_access
    model :membership
    model :message
    policy :ensure_valid_message
    step :mark_associated_mentions_as_read
    step :mark_thread_read
    step :publish_new_last_read_to_clients

    # @!visibility private
    class Contract
      attribute :channel_id, :integer
      attribute :thread_id, :integer
      attribute :message_id, :integer

      validates :thread_id, :channel_id, presence: true
    end

    private

    def fetch_thread(contract:)
      ::Chat::Thread.find_by(id: contract.thread_id, channel_id: contract.channel_id)
    end

    def fetch_message(contract:, thread:)
      ::Chat::Message.with_deleted.find_by(
        id: contract.message_id || thread.last_message_id,
        thread_id: contract.thread_id,
        chat_channel_id: contract.channel_id,
      )
    end

    def fetch_membership(guardian:, thread:)
      thread.membership_for(guardian.user)
    end

    def invalid_access(guardian:, thread:)
      guardian.can_join_chat_channel?(thread.channel)
    end

    def ensure_valid_message(message:, membership:)
      !membership.last_read_message_id || message.id >= membership.last_read_message_id
    end

    def mark_thread_read(membership:, message:)
      membership.mark_read!(message.id)
    end

    def mark_associated_mentions_as_read(thread:, guardian:, message:)
      ::Chat::Action::MarkMentionsRead.call(
        guardian.user,
        channel_ids: [thread.channel_id],
        thread_id: thread.id,
        message_id: message.id,
      )
    end

    def publish_new_last_read_to_clients(guardian:, thread:, message:)
      ::Chat::Publisher.publish_user_tracking_state!(guardian.user, thread.channel, message)
    end
  end
end
