# frozen_string_literal: true

require "json"

module Patreon
  class InvalidApiResponse < ::StandardError
  end

  class Api
    PATREON_URL = "https://www.patreon.com"
    ACCESS_TOKEN_INVALID = "dashboard.patreon.access_token_invalid"
    INVALID_RESPONSE = "patreon.error.invalid_response"

    CAMPAIGN_FIELDS = "fields%5Bcampaign%5D=created_at,name,patron_count"
    TIER_FIELDS = "fields%5Btier%5D=title,amount_cents,created_at"
    MEMBER_FIELDS =
      "fields%5Bmember%5D=full_name,last_charge_date,last_charge_status,currently_entitled_amount_cents,patron_status,email"
    USER_FIELDS = "fields%5Buser%5D=email,full_name"

    def self.campaign_data
      get("/api/oauth2/v2/campaigns?include=tiers,creator&#{CAMPAIGN_FIELDS}&#{TIER_FIELDS}")
    end

    def self.members_data(campaign_id, cursor = nil)
      url =
        "/api/oauth2/v2/campaigns/#{campaign_id}/members?include=currently_entitled_tiers,user&#{MEMBER_FIELDS}&#{USER_FIELDS}&#{TIER_FIELDS}&page%5Bcount%5D=1000"
      url += "&page%5Bcursor%5D=#{CGI.escape(cursor)}" if cursor.present?
      get(url)
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
          url: PATREON_URL,
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
        e = Patreon::InvalidApiResponse.new(response.body.presence || "")
        e.set_backtrace(caller)
        Discourse.warn_exception(e, message: I18n.t(INVALID_RESPONSE), env: { api_uri: uri })
      end

      { error: I18n.t(INVALID_RESPONSE) }
    end
  end
end
