# frozen_string_literal: true

require "discourse_dev"

module DiscourseDev
  class ApplicationRequest
    ANON_MULTIPLIER = 2
    CRAWLER_MULTIPLIER = 76
    LEGACY_OVERHEAD = 3

    WEEKEND_FACTOR = 0.7
    JITTER_RANGE = 0.30
    DRIFT_FLOOR = 0.5
    SPIKE_MIN = 2.0
    SPIKE_RANGE = 2.0

    def initialize
      settings = DiscourseDev.config.application_request
      @baseline = settings[:logged_in_browser_pageviews_per_day]
      @end_date = Date.yesterday
      @start_date = 2.years.ago.to_date
      @random = Random.new(DiscourseDev.config.seed || 1)
    end

    def populate!
      unless Discourse.allow_dev_populate?
        raise 'To run this rake task in a production site, set the value of `ALLOW_DEV_POPULATE` environment variable to "1"'
      end

      rows = build_rows
      puts "Seeding #{rows.size} application_requests rows from #{@start_date} to #{@end_date}"
      bulk_upsert(rows)
      rows.size
    end

    def self.populate!
      new.populate!
    end

    private

    def build_rows
      spike_dates = pick_spike_dates
      total_days = [(@end_date - @start_date).to_i, 1].max
      rows = []

      (@start_date..@end_date).each do |date|
        logged_in_browser = daily_logged_in_browser(date, total_days, spike_dates)
        anon_browser = (logged_in_browser * ANON_MULTIPLIER).round
        crawler = (logged_in_browser * CRAWLER_MULTIPLIER).round
        logged_in_legacy = (logged_in_browser * LEGACY_OVERHEAD).round
        anon_legacy = (anon_browser * LEGACY_OVERHEAD).round

        rows << [
          date,
          ::ApplicationRequest.req_types[:page_view_logged_in_browser],
          logged_in_browser,
        ]
        rows << [date, ::ApplicationRequest.req_types[:page_view_anon_browser], anon_browser]
        rows << [date, ::ApplicationRequest.req_types[:page_view_crawler], crawler]
        rows << [date, ::ApplicationRequest.req_types[:page_view_logged_in], logged_in_legacy]
        rows << [date, ::ApplicationRequest.req_types[:page_view_anon], anon_legacy]
      end
      rows
    end

    def daily_logged_in_browser(date, total_days, spike_dates)
      base = @baseline.to_f
      days_in = (date - @start_date).to_i
      drift = DRIFT_FLOOR + ((1.0 - DRIFT_FLOOR) * days_in / total_days)
      base *= drift
      base *= WEEKEND_FACTOR if date.saturday? || date.sunday?
      base *= (1.0 - JITTER_RANGE / 2) + (@random.rand * JITTER_RANGE)
      base *= (SPIKE_MIN + @random.rand * SPIKE_RANGE) if spike_dates.include?(date)
      [base.round, 1].max
    end

    def pick_spike_dates
      dates = Set.new
      (@start_date..@end_date)
        .group_by { |d| [d.year, d.month] }
        .each_value do |month_days|
          next if month_days.size < 2
          start_idx = @random.rand(month_days.size - 1)
          dates << month_days[start_idx]
          dates << month_days[start_idx + 1]
        end
      dates
    end

    def bulk_upsert(rows)
      return if rows.empty?
      values_sql = rows.map { |d, t, c| "('#{d}', #{t}, #{c})" }.join(",")
      DB.exec(<<~SQL)
        INSERT INTO application_requests (date, req_type, count)
        VALUES #{values_sql}
        ON CONFLICT (date, req_type) DO UPDATE SET count = EXCLUDED.count
      SQL
    end
  end
end
