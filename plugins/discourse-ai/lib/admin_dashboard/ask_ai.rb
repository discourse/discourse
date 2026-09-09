# frozen_string_literal: true

module DiscourseAi
  module AdminDashboard
    class AskAi
      def self.build(start_date:, end_date:, current_user:)
        return unless Guardian.new(current_user).is_admin?

        new(start_date:, end_date:).build
      end

      def initialize(start_date:, end_date:)
        @start_date = parse_date(start_date) || 29.days.ago.beginning_of_day
        @end_date = parse_date(end_date)&.end_of_day || Time.current.end_of_day
        if @start_date > @end_date
          @start_date = 29.days.ago.beginning_of_day
          @end_date = Time.current.end_of_day
        end
      end

      def build
        logs = AskAiLog.where(asked_at: @start_date..@end_date)
        questions, askers, average_ms =
          logs.pick(
            Arel.sql("COUNT(*)"),
            Arel.sql("COUNT(DISTINCT user_id)"),
            Arel.sql("AVG(time_to_first_answer_ms)"),
          )
        outcomes = logs.group(:ask_outcome).count
        daily_counts = logs.group("DATE(asked_at)").count

        {
          start_date: @start_date.to_date,
          end_date: @end_date.to_date,
          daily_asks:
            (@start_date.to_date..@end_date.to_date).map do |date|
              { x: date.iso8601, y: daily_counts.fetch(date, 0) }
            end,
          questions:,
          askers:,
          average_first_answer_ms: average_ms,
          outcomes:
            %w[answered no_answer failed cancelled].map do |outcome|
              { outcome:, count: outcomes.fetch(outcome, 0) }
            end + [{ outcome: "pending", count: outcomes.fetch(nil, 0) }],
        }
      end

      private

      def parse_date(value)
        Time.zone.parse(value.to_s)&.beginning_of_day if value.present?
      rescue ArgumentError, TypeError
        nil
      end
    end
  end
end
