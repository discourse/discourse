# frozen_string_literal: true

module Chat
  # This class is responsible for querying the user's current tracking
  # (read/unread) state based on membership for one or more channels
  # and/or one or more threads.
  #
  # Only channels with threading_enabled set to true will have thread
  # tracking queried.
  #
  # The unread counts are based on the user's last_read_message_id for
  # each membership, as well as the notification_level (in the case of
  # thread memberships) and the following/muted settings (in the case of
  # channel memberships).
  #
  # @param guardian [Guardian] The current user's guardian
  # @param channel_ids [Array<Integer>] The channel IDs to query. Must be provided
  #   if thread_ids are not.
  # @param thread_ids [Array<Integer>] The thread IDs to query. Must be provided
  #   if channel_ids are not. If channel_ids are also provided then these just further
  #   filter results.
  # @param include_missing_memberships [Boolean] If true, will include channels
  #   and threads where the user does not have a UserChatXMembership record,
  #   with zeroed out unread counts.
  # @param include_threads [Boolean] If true, will include thread tracking
  #   state in the query, otherwise only channel tracking will be queried.
  # @param include_read [Boolean] If true, will include tracking state where
  #   the user has 0 unread messages. If false, will only include tracking state
  #   where the user has > 0 unread messages. If include_missing_memberships is
  #   also true, this overrides that option.
  class TrackingStateReportQuery
    def self.call(
      guardian:,
      channel_ids: nil,
      thread_ids: nil,
      include_missing_memberships: false,
      include_threads: false,
      include_read: true,
      include_last_reply_details: false
    )
      report = ::Chat::TrackingStateReport.new

      if channel_ids.blank?
        report.channel_tracking = {}
      else
        report.channel_tracking =
          ::Chat::ChannelUnreadsQuery
            .call(
              channel_ids: channel_ids,
              user_id: guardian.user.id,
              include_missing_memberships: include_missing_memberships,
              include_read: include_read,
            )
            .map do |ct|
              [ct.channel_id, { mention_count: ct.mention_count, unread_count: ct.unread_count }]
            end
            .to_h
      end

      if !include_threads || (thread_ids.blank? && channel_ids.blank?)
        report.thread_tracking = {}
      else
        tracking =
          ::Chat::ThreadUnreadsQuery.call(
            channel_ids: channel_ids,
            thread_ids: thread_ids,
            user_id: guardian.user.id,
            include_missing_memberships: include_missing_memberships,
            include_read: include_read,
          )

        last_reply_details =
          DB.query(<<~SQL, tracking.map(&:thread_id)) if include_last_reply_details
            SELECT chat_threads.id AS thread_id, last_message.created_at
            FROM chat_threads
            INNER JOIN chat_messages AS last_message ON last_message.id = chat_threads.last_message_id
            WHERE chat_threads.id IN (?)
              AND last_message.deleted_at IS NULL
          SQL

        report.thread_tracking =
          tracking
            .map do |tt|
              data = {
                channel_id: tt.channel_id,
                mention_count: tt.mention_count,
                unread_count: tt.unread_count,
              }

              if include_last_reply_details
                data[:last_reply_created_at] = last_reply_details
                  .find { |details| details.thread_id == tt.thread_id }
                  &.created_at
              end

              [tt.thread_id, data]
            end
            .to_h
      end

      report
    end
  end
end
