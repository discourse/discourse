# frozen_string_literal: true

class GifsController < ApplicationController
  requires_login

  KLIPY_CATEGORIES_URL = "https://api.klipy.com/v2/categories"
  KLIPY_SEARCH_URL = "https://api.klipy.com/v2/search"
  PAGE_SIZE = 24
  MAX_QUERY_LENGTH = 100
  MAX_REQUESTS_PER_10_SECONDS = 20

  before_action :ensure_gifs_enabled
  before_action :ensure_klipy_api_key
  before_action :rate_limit

  def categories
    proxy_klipy_request(
      KLIPY_CATEGORIES_URL,
      {
        "type" => "featured",
        "country" => SiteSetting.klipy_country,
        "locale" => SiteSetting.klipy_locale,
        "contentfilter" => SiteSetting.klipy_content_filter,
      },
    )
  end

  def search
    query = params.require(:q)
    if !query.is_a?(String) || query.length > MAX_QUERY_LENGTH
      raise Discourse::InvalidParameters.new(:q)
    end

    proxy_klipy_request(
      KLIPY_SEARCH_URL,
      {
        "q" => query,
        "country" => SiteSetting.klipy_country,
        "locale" => SiteSetting.klipy_locale,
        "contentfilter" => SiteSetting.klipy_content_filter,
        "media_filter" => SiteSetting.klipy_file_detail,
        "limit" => PAGE_SIZE,
        "pos" => params[:pos].presence || "0",
      },
    )
  end

  private

  def ensure_gifs_enabled
    raise Discourse::NotFound if !SiteSetting.enable_gifs?
  end

  def ensure_klipy_api_key
    head :forbidden if SiteSetting.klipy_api_key.blank?
  end

  def rate_limit
    RateLimiter.new(current_user, "gif-search", MAX_REQUESTS_PER_10_SECONDS, 10.seconds).performed!
  end

  def proxy_klipy_request(url, query)
    # Excon only raises on unexpected statuses when `expects:` is set, so we omit
    # it and forward whatever status Klipy returns to the client as-is.
    response =
      Excon.get(
        url,
        headers: {
          "Accept" => "application/json",
        },
        query: query.merge("key" => SiteSetting.klipy_api_key),
        connect_timeout: 5,
        read_timeout: 5,
      )

    render plain: redact_api_key(response.body.to_s),
           status: response.status,
           content_type: "application/json"
  rescue Excon::Error
    head :bad_gateway
  end

  # Defense-in-depth: the key is never intentionally returned to the client, but
  # a Klipy error response could echo back the key we sent. Strip it just in case.
  def redact_api_key(body)
    api_key = SiteSetting.klipy_api_key
    return body if api_key.blank?

    [api_key, CGI.escape(api_key)].uniq
      .reduce(body) { |redacted_body, value| redacted_body.gsub(value, "[FILTERED]") }
  end
end
