# frozen_string_literal: true

module Chat
  # List messages of a channel before and after a specific target (id, date),
  # or fetching paginated messages from last read.
  #
  # @example
  #  Chat::ListChannelMessages.call(params: { channel_id: 2, **optional_params }, guardian:)
  #
  class ListChannelMessages
    include Service::Base

    # @!method self.call(guardian:, params:)
    #   @param [Guardian] guardian
    #   @param [Hash] params
    #   @option params [Integer] :channel_id
    #   @return [Service::Base::Context]

    params do
      attribute :channel_id, :integer
      attribute :page_size, :integer

      # If this is not present, then we just fetch messages with page_size
      # and direction.
      attribute :target_message_id, :integer # (optional)
      attribute :direction, :string # (optional)
      attribute :fetch_from_last_read, :boolean # (optional)
      attribute :target_date, :string # (optional)

      validates :channel_id, presence: true
      validates :page_size,
                numericality: {
                  less_than_or_equal_to: Chat::MessagesQuery::MAX_PAGE_SIZE,
                  greater_than_or_equal_to: 1,
                  only_integer: true,
                  only_numeric: true,
                },
                allow_nil: true
      validates :direction,
                inclusion: {
                  in: Chat::MessagesQuery::VALID_DIRECTIONS,
                },
                allow_nil: true

      after_validation { self.page_size ||= Chat::MessagesQuery::MAX_PAGE_SIZE }
    end

    model :channel
    policy :can_view_channel
    model :membership, optional: true
    model :target_message_id, optional: true
    policy :target_message_exists
    model :messages, optional: true
    model :thread_ids, optional: true
    model :tracking, optional: true
    model :thread_participants, optional: true
    model :thread_memberships, optional: true
    step :update_membership_last_viewed_at
    step :update_user_last_channel

    private

    def fetch_channel(params:)
      ::Chat::Channel.includes(:chatable).find_by(id: params.channel_id)
    end

    def fetch_membership(channel:, guardian:)
      channel.membership_for(guardian.user)
    end

    def can_view_channel(guardian:, channel:)
      guardian.can_preview_chat_channel?(channel)
    end

    def fetch_target_message_id(params:, membership:)
      if params.fetch_from_last_read
        membership&.last_read_message_id
      else
        params.target_message_id
      end
    end

    def target_message_exists(channel:, guardian:, target_message_id:)
      return true if target_message_id.blank?

      target_message =
        Chat::Message.with_deleted.find_by(id: target_message_id, chat_channel: channel)
      return false if target_message.blank?

      return true if !target_message.trashed?
      if target_message.trashed? && target_message.user_id == guardian.user.id || guardian.is_staff?
        return true
      end

      context[:target_message_id] = nil
      true
    end

    def fetch_messages(channel:, params:, guardian:, target_message_id:)
      messages_data =
        ::Chat::MessagesQuery.call(
          channel:,
          guardian:,
          target_message_id:,
          include_thread_messages: !channel.threading_enabled?,
          **params.slice(:page_size, :direction, :target_date),
        )

      context[:can_load_more_past] = messages_data[:can_load_more_past]
      context[:can_load_more_future] = messages_data[:can_load_more_future]
      context[:target_message_id] = messages_data[:target_message_id]

      messages_data[:target_message] = (
        if messages_data[:target_message]&.thread_reply? &&
             (channel.threading_enabled? || messages_data[:target_message].thread&.force)
          []
        else
          [messages_data[:target_message]]
        end
      )

      [
        messages_data[:messages],
        messages_data[:past_messages]&.reverse,
        messages_data[:target_message],
        messages_data[:future_messages],
      ].flatten.compact
    end

    def fetch_thread_ids(messages:)
      messages.map(&:thread_id).compact.uniq
    end

    def fetch_tracking(guardian:, thread_ids:)
      ::Chat::TrackingStateReportQuery.(guardian:, thread_ids:, include_threads: true)
    end

    def fetch_thread_participants(messages:, thread_ids:)
      return if thread_ids.blank?

      ::Chat::ThreadParticipantQuery.(thread_ids:)
    end

    def fetch_thread_memberships(guardian:, thread_ids:)
      return if thread_ids.blank?

      ::Chat::UserChatThreadMembership.where(thread_id: thread_ids, user_id: guardian.user.id)
    end

    def update_membership_last_viewed_at(guardian:, membership:)
      Scheduler::Defer.later "Chat::ListChannelMessages - defer update_membership_last_viewed_at" do
        membership&.update!(last_viewed_at: Time.zone.now)
      end
    end

    def update_user_last_channel(guardian:, channel:)
      Scheduler::Defer.later "Chat::ListChannelMessages - defer update_user_last_channel" do
        next if guardian.user.custom_fields[::Chat::LAST_CHAT_CHANNEL_ID] == channel.id
        guardian.user.upsert_custom_fields(::Chat::LAST_CHAT_CHANNEL_ID => channel.id)
      end
    end
  end
end
