# frozen_string_literal: true

require "open-uri"

task "javascript:update_constants" => :environment do
  timezone_definitions =
    "https://raw.githubusercontent.com/moment/moment-timezone/develop/data/meta/latest.json"

  unused_regions = %w[
    ecbtarget
    federalreserve
    federalreservebanks
    fedex
    nerc
    unitednations
    ups
    nyse
  ]

  holidays_country_overrides = { "gr" => "el" }

  require "holidays" if !defined?(Holidays)

  holiday_regions = Holidays.available_regions.map(&:to_s) - unused_regions

  time_zone_to_region = {}
  data = JSON.parse(URI.parse(timezone_definitions).open.read)
  data["zones"].sort.each do |timezone, timezone_data|
    country_code = timezone_data["countries"].first.downcase

    if holidays_country_overrides.include?(country_code)
      country_code = holidays_country_overrides[country_code]
    end

    next if !holiday_regions.include?(country_code)
    time_zone_to_region[timezone] = country_code
  end

  write_template(
    "../../../plugins/discourse-calendar/assets/javascripts/discourse/lib/regions.js",
    "update_constants",
    <<~JS,
    export const HOLIDAY_REGIONS = #{holiday_regions.to_json};

    export const TIME_ZONE_TO_REGION = #{time_zone_to_region.to_json};
  JS
  )
end
