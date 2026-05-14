# frozen_string_literal: true

module Jobs
  class RollupSiteTrafficPageviews < ::Jobs::Scheduled
    every 5.minutes

    def execute(args = {})
      return if !SiteSetting.persist_browser_pageview_events

      rollup_dates(args).each { |date| BrowserPageviewDailyAggregate::Rollup.call(date) }
    end

    private

    def rollup_dates(args)
      return [args[:date].to_date] if args[:date].present?

      [Time.zone.yesterday.to_date, Time.zone.today]
    end
  end
end
