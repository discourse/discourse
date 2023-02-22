# frozen_string_literal: true
require "uri"
require "net/http"
require "json"

class Oauth2Pop3Token
  class << self
    def refresh_access_token()
      access_token, refresh_token, expires_in = self.get_new_tokens()

      SiteSetting.set_and_log("pop3_polling_oauth2_refresh_token", refresh_token)
      Discourse.redis.setex(
        Jobs::PollMailbox::POLL_MAILBOX_OAUTH2_AUTH_TOKEN_KEY,
        expires_in.seconds,
        access_token,
      )
    end

    def refresh_access_token_if_needed()
      if Discourse.redis.get(Jobs::PollMailbox::POLL_MAILBOX_OAUTH2_AUTH_TOKEN_KEY) == nil
        self.refresh_access_token()
        Rails.logger.info("OAUTH2 POP3 access token expired, refreshed.")
      end
    end

    private

    def get_new_tokens()
      uri = URI(SiteSetting.pop3_polling_oauth2_endpoint)
      res =
        Net::HTTP.post_form(
          uri,
          "client_id" => SiteSetting.pop3_polling_oauth2_clientid,
          "refresh_token" => SiteSetting.pop3_polling_oauth2_refresh_token,
          "grant_type" => "refresh_token",
          "scope" => SiteSetting.pop3_polling_oauth2_scope,
        )

      raise Oauth2RefreshFail if res.code != "200"

      res_json = JSON.parse(res.body)

      access_token = res_json["access_token"]
      refresh_token = res_json["refresh_token"]
      expires_in = res_json["expires_in"]

      [access_token, refresh_token, expires_in]
    end
  end
end

class Oauth2RefreshFail < StandardError
end
