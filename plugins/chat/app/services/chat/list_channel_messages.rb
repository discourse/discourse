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
    policy :target_message_exists, class_name: Chat::Channel::Policy::MessageExistence
    model :metadata, optional: true
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
      return params.target_message_id unless params.fetch_from_last_read
      membership&.last_read_message_id
    end

    def fetch_metadata(channel:, guardian:, target_message_id:, params:)
      ::Chat::MessagesQuery.call(
        channel:,
        guardian:,
        target_message_id:,
        include_thread_messages: !channel.threading_enabled?,
        **params.slice(:page_size, :direction, :target_date),
      )
    end

    def fetch_messages(metadata:)
      [
        metadata[:messages],
        metadata[:past_messages]&.reverse,
        (metadata[:target_message] unless metadata[:target_message]&.thread_reply?),
        metadata[:future_messages],
      ].flatten.compact
    end

    def fetch_thread_ids(messages:)
      messages.filter_map(&:thread_id).uniq
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
