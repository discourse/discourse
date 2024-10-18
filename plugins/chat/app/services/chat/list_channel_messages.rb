# frozen_string_literal: true

module Chat
  # List messages of a channel before and after a specific target (id, date),
  # or fetching paginated messages from last read.
  #
  # @example
  #  Chat::ListChannelMessages.call(channel_id: 2, guardian: guardian, **optional_params)
  #
  class ListChannelMessages
    include Service::Base

    # @!method call(guardian:)
    #   @param [Integer] channel_id
    #   @param [Guardian] guardian
    #   @return [Service::Base::Context]

    contract do
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
                  less_than_or_equal_to: ::Chat::MessagesQuery::MAX_PAGE_SIZE,
                  only_integer: true,
                },
                allow_nil: true
      validates :direction,
                inclusion: {
                  in: Chat::MessagesQuery::VALID_DIRECTIONS,
                },
                allow_nil: true
    end
    model :channel
    policy :can_view_channel
    model :membership, optional: true
    step :enabled_threads?
    step :determine_target_message_id
    policy :target_message_exists
    step :fetch_messages
    step :fetch_thread_ids
    step :fetch_tracking
    step :fetch_thread_participants
    step :fetch_thread_memberships
    step :update_membership_last_viewed_at
    step :update_user_last_channel

    private

    def fetch_channel(contract:)
      ::Chat::Channel.includes(:chatable).find_by(id: contract.channel_id)
    end

    def fetch_membership(channel:, guardian:)
      channel.membership_for(guardian.user)
    end

    def enabled_threads?(channel:)
      context[:enabled_threads] = channel.threading_enabled
    end

    def can_view_channel(guardian:, channel:)
      guardian.can_preview_chat_channel?(channel)
    end

    def determine_target_message_id(contract:, membership:)
      if contract.fetch_from_last_read
        context[:target_message_id] = membership&.last_read_message_id
      else
        context[:target_message_id] = contract.target_message_id
      end
    end

    def target_message_exists(channel:, guardian:)
      return true if context.target_message_id.blank?

      target_message =
        Chat::Message.with_deleted.find_by(id: context.target_message_id, chat_channel: channel)
      return false if target_message.blank?

      return true if !target_message.trashed?
      if target_message.trashed? && target_message.user_id == guardian.user.id || guardian.is_staff?
        return true
      end

      context[:target_message_id] = nil
      true
    end

    def fetch_messages(channel:, contract:, guardian:, enabled_threads:)
      messages_data =
        ::Chat::MessagesQuery.call(
          channel: channel,
          guardian: guardian,
          target_message_id: context.target_message_id,
          include_thread_messages: !enabled_threads,
          page_size: contract.page_size || Chat::MessagesQuery::MAX_PAGE_SIZE,
          direction: contract.direction,
          target_date: contract.target_date,
        )

      context[:can_load_more_past] = messages_data[:can_load_more_past]
      context[:can_load_more_future] = messages_data[:can_load_more_future]
      context[:target_message_id] = messages_data[:target_message_id]

      messages_data[:target_message] = (
        if messages_data[:target_message]&.thread_reply? &&
             (enabled_threads || messages_data[:target_message].thread&.force)
          []
        else
          [messages_data[:target_message]]
        end
      )

      context[:messages] = [
        messages_data[:messages],
        messages_data[:past_messages]&.reverse,
        messages_data[:target_message],
        messages_data[:future_messages],
      ].flatten.compact
    end

    def fetch_tracking(guardian:)
      context[:tracking] = {}

      return if !context.thread_ids.present?

      context[:tracking] = ::Chat::TrackingStateReportQuery.call(
        guardian: guardian,
        thread_ids: context.thread_ids,
        include_threads: true,
      )
    end

    def fetch_thread_ids(messages:)
      context[:thread_ids] = messages.map(&:thread_id).compact.uniq
    end

    def fetch_thread_participants(messages:)
      return if context.thread_ids.empty?

      context[:thread_participants] = ::Chat::ThreadParticipantQuery.call(
        thread_ids: context.thread_ids,
      )
    end

    def fetch_thread_memberships(guardian:)
      return if context.thread_ids.empty?

      context[:thread_memberships] = ::Chat::UserChatThreadMembership.where(
        thread_id: context.thread_ids,
        user_id: guardian.user.id,
      )
    end

    def update_membership_last_viewed_at(guardian:)
      Scheduler::Defer.later "Chat::ListChannelMessages - defer update_membership_last_viewed_at" do
        context.membership&.update!(last_viewed_at: Time.zone.now)
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
