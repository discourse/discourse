# frozen_string_literal: true

require "json"

module Patreon
  class InvalidApiResponse < ::StandardError
  end

  class Api
    ACCESS_TOKEN_INVALID = "dashboard.patreon.access_token_invalid"
    INVALID_RESPONSE = "patreon.error.invalid_response"

    def self.campaign_data
      adapter = ApiVersion.current
      get(adapter.campaign_data_url, base_url: adapter.api_base_url)
    end

    def self.get(uri, base_url: ApiVersion.current.api_base_url)
      limiter_hr =
        RateLimiter.new(nil, "patreon_api_hr", SiteSetting.max_patreon_api_reqs_per_hr, 1.hour)
      limiter_day =
        RateLimiter.new(nil, "patreon_api_day", SiteSetting.max_patreon_api_reqs_per_day, 1.day)

      limiter_hr.performed! unless limiter_hr.can_perform?

      limiter_day.performed! unless limiter_day.can_perform?

      full_url = "#{base_url}#{uri}"
      Rails.logger.warn("Patreon API request: GET #{full_url}") if SiteSetting.patreon_verbose_log

      response =
        Faraday.new(
          url: base_url,
          headers: {
            "Authorization" => "Bearer #{SiteSetting.patreon_creator_access_token}",
          },
        ).get(uri)

      limiter_hr.performed!
      limiter_day.performed!

      if SiteSetting.patreon_verbose_log
        Rails.logger.warn(
          "Patreon API response: status=#{response.status} body_size=#{response.body&.size || 0}",
        )
      end

      case response.status
      when 200
        return JSON.parse response.body
      when 401
        ProblemCheckTracker[:access_token_invalid].problem!
      else
        e = Patreon::InvalidApiResponse.new(response.body.presence || "")
        e.set_backtrace(caller)
        Discourse.warn_exception(e, message: I18n.t(INVALID_RESPONSE), env: { api_uri: uri })
      end

      { error: I18n.t(INVALID_RESPONSE) }
    end
  end
end
