# frozen_string_literal: true

class BrowserPageviewReferrerDailyRollup < ActiveRecord::Base
  def self.aggregate(start_date:, end_date:)
    host = BrowserPageviewReferrerInspector.normalize_host(Discourse.current_hostname)
    return if host.nil?

    escaped_host = host.gsub(/[\\_%]/) { |char| "\\#{char}" }

    DB.exec(
      <<~SQL,
        INSERT INTO browser_pageview_referrer_daily_rollups (date, normalized_referrer, count, logged_in_count)
        SELECT
          created_at::date AS date,
          normalized_referrer,
          COUNT(*) AS count,
          COUNT(*) FILTER (WHERE user_id IS NOT NULL) AS logged_in_count
        FROM browser_pageview_events
        WHERE created_at >= :start_date
          AND created_at < :end_date
          AND (
            normalized_referrer IS NULL
            OR (
              normalized_referrer <> :host_exact
              AND normalized_referrer NOT LIKE :host_path_prefix ESCAPE '\\'
              AND normalized_referrer NOT LIKE :host_query_prefix ESCAPE '\\'
            )
          )
        GROUP BY date, normalized_referrer
        ON CONFLICT (date, normalized_referrer) DO UPDATE
        SET count = EXCLUDED.count,
            logged_in_count = EXCLUDED.logged_in_count
      SQL
      start_date: start_date.to_date,
      end_date: end_date.to_date + 1,
      host_exact: host,
      host_path_prefix: "#{escaped_host}/%",
      host_query_prefix: "#{escaped_host}?%",
    )
  end
end

# == Schema Information
#
# Table name: browser_pageview_referrer_daily_rollups
#
#  id                  :bigint           not null, primary key
#  count               :bigint           not null
#  date                :date             not null
#  logged_in_count     :bigint           not null
#  normalized_referrer :string(2000)
#
# Indexes
#
#  idx_bprd_rollups_date_referrer_unique  (date,normalized_referrer) UNIQUE NULLS NOT DISTINCT
#
