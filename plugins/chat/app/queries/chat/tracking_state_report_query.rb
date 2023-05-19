# frozen_string_literal: true

module Chat
  class TrackingStateReportQuery
    def self.call(
      guardian:,
      channel_ids: nil,
      thread_ids: nil,
      include_missing_memberships: false,
      include_threads: false,
      include_read: true
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
        report.thread_tracking =
          ::Chat::ThreadUnreadsQuery
            .call(
              channel_ids: channel_ids,
              thread_ids: thread_ids,
              user_id: guardian.user.id,
              include_missing_memberships: include_missing_memberships,
              include_read: include_read,
            )
            .map do |tt|
              [
                tt.thread_id,
                {
                  channel_id: tt.channel_id,
                  mention_count: tt.mention_count,
                  unread_count: tt.unread_count,
                },
              ]
            end
            .to_h
      end

      report
    end
  end
end
