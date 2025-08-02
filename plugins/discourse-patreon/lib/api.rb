# frozen_string_literal: true

require "json"

module ::Patreon
  class InvalidApiResponse < ::StandardError
  end

  class Api
    ACCESS_TOKEN_INVALID = "dashboard.patreon.access_token_invalid".freeze
    INVALID_RESPONSE = "patreon.error.invalid_response".freeze

    def self.campaign_data
      get(
        "/oauth2/api/current_user/campaigns?include=rewards,creator,goals,pledges&page[count]=100",
      )
    end

    def self.get(uri)
      limiter_hr =
        RateLimiter.new(nil, "patreon_api_hr", SiteSetting.max_patreon_api_reqs_per_hr, 1.hour)
      limiter_day =
        RateLimiter.new(nil, "patreon_api_day", SiteSetting.max_patreon_api_reqs_per_day, 1.day)

      limiter_hr.performed! unless limiter_hr.can_perform?

      limiter_day.performed! unless limiter_day.can_perform?

      response =
        Faraday.new(
          url: "https://api.patreon.com",
          headers: {
            "Authorization" => "Bearer #{SiteSetting.patreon_creator_access_token}",
          },
        ).get(uri)

      limiter_hr.performed!
      limiter_day.performed!

      case response.status
      when 200
        return JSON.parse response.body
      when 401
        ProblemCheckTracker[:access_token_invalid].problem!
      else
        e = ::Patreon::InvalidApiResponse.new(response.body.presence || "")
        e.set_backtrace(caller)
        Discourse.warn_exception(e, message: I18n.t(INVALID_RESPONSE), env: { api_uri: uri })
      end

      { error: I18n.t(INVALID_RESPONSE) }
    end
  end
end
