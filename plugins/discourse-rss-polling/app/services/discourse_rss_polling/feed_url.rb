# frozen_string_literal: true

module DiscourseRssPolling
  module FeedUrl
    CREDENTIAL_PARAMS = %w[api_key api_username]
    HTTP_URL = %r{\Ahttps?://}i

    def self.http?(url)
      url.to_s.match?(HTTP_URL)
    end

    def self.redact(url)
      split_credentials(url).first
    end

    # Returns [url_without_credentials, { "api_key" => ..., "api_username" => ... }].
    def self.split_credentials(url)
      uri = URI.parse(url.to_s.strip)
      return url.to_s, {} if uri.query.blank?

      params = CGI.parse(uri.query)
      credentials = CREDENTIAL_PARAMS.to_h { |param| [param, params.delete(param)&.first] }
      uri.query = params.empty? ? nil : URI.encode_www_form(params)
      [uri.to_s, credentials]
    rescue URI::InvalidURIError
      [url.to_s.split("?", 2).first.to_s, {}]
    end
  end
end
