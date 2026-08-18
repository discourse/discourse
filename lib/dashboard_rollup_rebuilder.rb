# frozen_string_literal: true

# Recomputes the rollup tables behind the admin dashboard from their source
# records. Replaying never drops data that can no longer be derived, because
# browser pageview events are pruned long before the rollups are. The flip side
# is that rows whose source events are gone are refreshed in place rather than
# removed, so a replay cannot retract counts that were once written.
class DashboardRollupRebuilder
  NAMES = %w[
    browser_pageview_country
    browser_pageview_referrer
    browser_pageview_session_engagement
    browser_pageview_crawler
    category_activity
    user_visit
  ].freeze

  def self.names
    NAMES
  end

  def self.known?(name)
    NAMES.include?(name.to_s)
  end

  def self.rebuild!(name = nil, io: $stdout)
    new(io: io).rebuild!(name)
  end

  def initialize(io: $stdout)
    @io = io
  end

  def rebuild!(name = nil)
    rollups = name ? [name.to_s] : NAMES

    rollups.each do |rollup|
      log "Rebuilding #{rollup} rollups for #{RailsMultisite::ConnectionManagement.current_db}"
      public_send(:"rebuild_#{rollup}")
    end
  end

  def rebuild_browser_pageview_country
    aggregate_browser_pageviews(BrowserPageviewCountryDailyRollup)
  end

  def rebuild_browser_pageview_referrer
    aggregate_browser_pageviews(BrowserPageviewReferrerDailyRollup)
  end

  def rebuild_browser_pageview_session_engagement
    aggregate_browser_pageviews(BrowserPageviewSessionEngagementDailyRollup)
  end

  def rebuild_browser_pageview_crawler
    aggregate_browser_pageviews(BrowserPageviewCrawlerDailyRollup)
  end

  def rebuild_category_activity
    CategoryActivityDailyRollup.rebuild!
  end

  def rebuild_user_visit
    start_date = UserVisit.minimum(:visited_at)&.to_date
    return log("  no user visits, skipping") if start_date.nil?

    UserVisitDailyRollup.aggregate(start_date: start_date, end_date: Time.zone.today)
  end

  private

  def aggregate_browser_pageviews(rollup)
    start_date = earliest_event_date
    return log("  no browser pageview events, skipping") if start_date.nil?

    rollup.aggregate(start_date: start_date, end_date: Time.zone.today)
  end

  def earliest_event_date
    @earliest_event_date ||=
      BrowserPageviewEvent
        .where(BrowserPageviewEvent.rollup_source_condition)
        .minimum(:created_at)
        &.to_date
  end

  def log(message)
    @io.puts(message)
  end
end
