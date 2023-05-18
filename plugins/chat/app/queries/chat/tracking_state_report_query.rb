# frozen_string_literal: true

module Chat
  class TrackingStateReportQuery
    def self.call(
      guardian:,
      channel_ids: [],
      thread_ids: [],
      include_missing_memberships: false,
      include_threads: false,
      include_zero_unreads: true
    )
      report = ::Chat::TrackingStateReport.new

      if channel_ids.empty?
        report.channel_tracking = {}
      else
        report.channel_tracking =
          ::Chat::ChannelUnreadsQuery
            .call(
              channel_ids: channel_ids,
              user_id: guardian.user.id,
              include_missing_memberships: include_missing_memberships,
              include_zero_unreads: include_zero_unreads,
            )
            .map do |ct|
              [ct.channel_id, { mention_count: ct.mention_count, unread_count: ct.unread_count }]
            end
            .to_h
      end

      if !include_threads || (thread_ids.empty? && channel_ids.empty?)
        report.thread_tracking = {}
      else
        report.thread_tracking =
          ::Chat::ThreadUnreadsQuery
            .call(
              channel_ids: channel_ids,
              thread_ids: thread_ids,
              user_id: guardian.user.id,
              include_missing_memberships: include_missing_memberships,
              include_zero_unreads: include_zero_unreads,
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
