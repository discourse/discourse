# frozen_string_literal: true

require "discourse_dev"

module DiscourseDev
  class ApplicationRequest
    ANON_MULTIPLIER = 2
    CRAWLER_MULTIPLIER = 76
    LEGACY_OVERHEAD = 3

    COUNTRY_DISTRIBUTION = [
      ["US", 42],
      ["GB", 13],
      ["DE", 9],
      ["CA", 8],
      ["AU", 6],
      ["FR", 5],
      ["IN", 4],
      ["NL", 3],
    ].freeze

    SOURCE_DISTRIBUTION = [
      [BrowserPageviewDailyAggregate::DIRECT_SOURCE_NAME, 44],
      ["google.com", 20],
      ["news.ycombinator.com", 10],
      ["github.com", 8],
      ["reddit.com/r/programming", 6],
      ["reddit.com/r/ruby", 5],
      ["duckduckgo.com", 3],
      ["meta.discourse.org", 2],
      ["reddit.com/r/discourse", 2],
    ].freeze

    WEEKEND_FACTOR = 0.7
    JITTER_RANGE = 0.30
    DRIFT_FLOOR = 0.5
    SPIKE_MIN = 2.0
    SPIKE_RANGE = 2.0

    def initialize
      settings = DiscourseDev.config.application_request
      @baseline = settings[:logged_in_browser_pageviews_per_day]
      @end_date = Date.current
      @start_date = 2.years.ago.to_date
      @random = Random.new(DiscourseDev.config.seed || 1)
    end

    def populate!
      unless Discourse.allow_dev_populate?
        raise 'To run this rake task in a production site, set the value of `ALLOW_DEV_POPULATE` environment variable to "1"'
      end

      application_request_rows, pageview_daily_aggregate_rows = build_rows

      puts "Seeding #{application_request_rows.size} application_requests rows from #{@start_date} to #{@end_date}"
      bulk_upsert_application_requests(application_request_rows)

      puts "Seeding #{pageview_daily_aggregate_rows.size} browser_pageview_daily_aggregate rows"
      bulk_upsert_pageview_daily_aggregates(
        :browser_pageview_daily_aggregates,
        pageview_daily_aggregate_rows,
      )

      application_request_rows.size + pageview_daily_aggregate_rows.size
    end

    def self.populate!
      new.populate!
    end

    private

    def build_rows
      spike_dates = pick_spike_dates
      total_days = [(@end_date - @start_date).to_i, 1].max
      application_request_rows = []
      pageview_daily_aggregate_rows = []

      (@start_date..@end_date).each do |date|
        logged_in_browser = daily_logged_in_browser(date, total_days, spike_dates)
        anon_browser = (logged_in_browser * ANON_MULTIPLIER).round
        crawler = (logged_in_browser * CRAWLER_MULTIPLIER).round
        logged_in_legacy = (logged_in_browser * LEGACY_OVERHEAD).round
        anon_legacy = (anon_browser * LEGACY_OVERHEAD).round

        application_request_rows << [
          date,
          ::ApplicationRequest.req_types[:page_view_logged_in_browser],
          logged_in_browser,
        ]
        application_request_rows << [
          date,
          ::ApplicationRequest.req_types[:page_view_anon_browser],
          anon_browser,
        ]
        application_request_rows << [
          date,
          ::ApplicationRequest.req_types[:page_view_crawler],
          crawler,
        ]
        application_request_rows << [
          date,
          ::ApplicationRequest.req_types[:page_view_logged_in],
          logged_in_legacy,
        ]
        application_request_rows << [
          date,
          ::ApplicationRequest.req_types[:page_view_anon],
          anon_legacy,
        ]

        append_pageview_daily_aggregate_rows(
          pageview_daily_aggregate_rows,
          date,
          logged_in_browser,
          true,
        )
        append_pageview_daily_aggregate_rows(
          pageview_daily_aggregate_rows,
          date,
          anon_browser,
          false,
        )
      end

      [application_request_rows, pageview_daily_aggregate_rows]
    end

    def append_pageview_daily_aggregate_rows(rows, date, total_count, is_logged_in)
      weighted_counts(total_count, COUNTRY_DISTRIBUTION).each do |country_code, country_count|
        weighted_counts(country_count, SOURCE_DISTRIBUTION).each do |source_name, source_count|
          rows << [date, country_code, source_name, is_logged_in, source_count]
        end
      end
    end

    def weighted_counts(total_count, distribution)
      total_count = total_count.to_i
      return [] if total_count <= 0

      total_weight = distribution.sum { |_, weight| weight }
      remaining = total_count

      distribution
        .map
        .with_index do |(key, weight), index|
          count =
            if index == distribution.length - 1
              remaining
            else
              [(total_count * weight.to_f / total_weight).round, remaining].min
            end

          remaining -= count
          [key, count]
        end
        .select { |_, count| count > 0 }
    end

    def daily_logged_in_browser(date, total_days, spike_dates)
      base = @baseline.to_f
      days_in = (date - @start_date).to_i
      drift = DRIFT_FLOOR + ((1.0 - DRIFT_FLOOR) * days_in / total_days)
      base *= drift
      base *= WEEKEND_FACTOR if date.saturday? || date.sunday?
      base *= (1.0 - JITTER_RANGE / 2) + (@random.rand * JITTER_RANGE)
      base *= (SPIKE_MIN + @random.rand * SPIKE_RANGE) if spike_dates.include?(date)
      # Today is partial-by-design — scale the seeded count by the fraction
      # of UTC hours elapsed so the rightmost bar reads as a real
      # in-progress day rather than a full one.
      base *= (Time.now.utc.hour + 1) / 24.0 if date == Date.current
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

    def bulk_upsert_application_requests(rows)
      return if rows.empty?
      values_sql = rows.map { |d, t, c| "('#{d}', #{t}, #{c})" }.join(",")
      DB.exec(<<~SQL)
        INSERT INTO application_requests (date, req_type, count)
        VALUES #{values_sql}
        ON CONFLICT (date, req_type) DO UPDATE SET count = EXCLUDED.count
      SQL
    end

    def bulk_upsert_pageview_daily_aggregates(table_name, rows)
      return if rows.empty?

      values_sql =
        rows
          .map do |date, country_code, source_name, is_logged_in, count|
            quoted_country_code = ActiveRecord::Base.connection.quote(country_code)
            quoted_source_name = ActiveRecord::Base.connection.quote(source_name)
            "('#{date}', #{quoted_country_code}, #{quoted_source_name}, #{is_logged_in}, #{count})"
          end
          .join(",")

      DB.exec(
        "DELETE FROM #{table_name} WHERE date >= :start_date AND date <= :end_date",
        start_date: @start_date,
        end_date: @end_date,
      )

      DB.exec(<<~SQL)
        INSERT INTO #{table_name} (date, country_code, source_name, is_logged_in, count)
        VALUES #{values_sql}
        ON CONFLICT (date, country_code, source_name, is_logged_in) WHERE country_code IS NOT NULL
        DO UPDATE SET count = EXCLUDED.count
      SQL
    end
  end
end
