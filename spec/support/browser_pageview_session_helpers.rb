# frozen_string_literal: true

module BrowserPageviewSessionHelpers
  def record_visit(at:, url: "https://example.com/", user_id: nil, engaged_for: nil)
    pageview = Fabricate(:browser_pageview_event, url: url, user_id: user_id, created_at: at)

    if engaged_for
      Fabricate(:browser_pageview_engagement, event: pageview, created_at: at + engaged_for)
    end

    pageview
  end

  def aggregate_session_rollup
    BrowserPageviewSessionDailyRollup.aggregate(
      start_date: 1.year.ago.to_date,
      end_date: Date.current,
    )
  end
end
