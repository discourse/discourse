# frozen_string_literal: true

module DiscourseDataExplorer
  class QueryRunRateLimiter
    def self.perform!(query_id:)
      RateLimiter.new(
        nil,
        "api-query-run-10-sec",
        GlobalSetting.max_data_explorer_api_reqs_per_10_seconds,
        10.seconds,
      ).performed!
    rescue RateLimiter::LimitExceeded => error
      if GlobalSetting.max_data_explorer_api_req_mode.include?("warn")
        Discourse.warn("Query run 10 second rate limit exceeded", query_id:)
      end
      raise error if GlobalSetting.max_data_explorer_api_req_mode.include?("block")
    end
  end
end
