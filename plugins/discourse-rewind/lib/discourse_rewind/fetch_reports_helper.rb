# frozen_string_literal: true

module DiscourseRewind
  module FetchReportsHelper
    extend self

    REWIND_REPORT_VERSION = "1"
    CACHE_DURATION = Rails.env.development? ? 10.seconds : 3.days

    def cache_key(username, year)
      "rewind:#{username}:#{year}:v#{REWIND_REPORT_VERSION}"
    end

    def load_reports_from_cache(username, year)
      reports = Discourse.redis.get(cache_key(username, year))
      return nil if !reports
      MultiJson.load(reports, symbolize_keys: true)
    end

    def cache_reports(username, year, reports)
      Discourse.redis.setex(cache_key(username, year), CACHE_DURATION, MultiJson.dump(reports))
    end
  end
end
