# frozen_string_literal: true

class BrowserPageviewDailyAggregate::Rollup
  BATCH_SIZE = 10_000

  def self.call(date)
    new(date).call
  end

  def initialize(date)
    @date = date.to_date
  end

  def call
    rows = aggregate_rows

    BrowserPageviewDailyAggregate.transaction do
      BrowserPageviewDailyAggregate.where(date: @date).delete_all
      BrowserPageviewDailyAggregate.insert_all!(rows) if rows.present?
    end
  end

  private

  def aggregate_rows
    counts = Hash.new(0)

    BrowserPageviewEvent
      .where(created_at: day_start...day_end)
      .in_batches(of: BATCH_SIZE) do |events|
        events
          .pluck(:created_at, :country_code, :user_id, :referrer)
          .each do |created_at, country_code, user_id, referrer|
            source_name = BrowserPageviewReferrerInspector.source_name(referrer)
            key = [created_at.utc.to_date, country_code, source_name, user_id.present?]
            counts[key] += 1
          end
      end

    counts.map do |(date, country_code, source_name, is_logged_in), count|
      {
        date: date,
        country_code: country_code,
        source_name: source_name,
        is_logged_in: is_logged_in,
        count: count,
      }
    end
  end

  def day_start
    @day_start ||= Time.utc(@date.year, @date.month, @date.day)
  end

  def day_end
    day_start + 1.day
  end
end
