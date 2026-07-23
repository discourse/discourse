# frozen_string_literal: true

class CrawlerScorer
  def self.score!(window_start:, window_end:)
    DB.exec(
      SQL,
      window_start: window_start,
      window_end: window_end,
      ua_regex: SiteSetting.crawler_automation_user_agents,
    )
  end

  SQL = <<~SQL
    UPDATE browser_pageview_events events
    SET crawler = detected.crawler
    FROM (
      SELECT e.id,
             (
               (:ua_regex <> '' AND e.user_agent ~* :ua_regex)
               OR NOT EXISTS (
                 SELECT 1
                 FROM browser_pageview_session_engagements se
                 WHERE se.session_id = e.session_id
               )
             ) AS crawler
      FROM browser_pageview_events e
      WHERE e.created_at >= :window_start
        AND e.created_at <  :window_end
    ) detected
    WHERE events.id = detected.id
      AND events.crawler <> detected.crawler
  SQL
end
