# frozen_string_literal: true

module Jobs
  class RollupSiteTrafficPageviews < ::Jobs::Scheduled
    every 5.minutes

    def execute(args = {})
      return if !SiteSetting.site_traffic_data_layer_enabled

      rollup_dates(args).each do |date|
        PageviewDailyAggregate.rollup!(date)
        PageviewDailyAggregateBeacon.rollup!(date)
      end
    end

    private

    def rollup_dates(args)
      return [args[:date].to_date] if args[:date].present?

      [Time.zone.yesterday.to_date, Time.zone.today]
    end
  end
end
