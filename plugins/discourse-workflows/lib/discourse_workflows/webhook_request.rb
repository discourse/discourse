# frozen_string_literal: true

module DiscourseWorkflows
  class WebhookRequest
    attr_reader :method, :path, :headers, :params, :query, :body, :raw_body, :ip, :ips, :webhook_url

    def initialize(
      method:,
      path:,
      headers: {},
      params: {},
      query: {},
      body: {},
      raw_body: nil,
      ip: nil,
      ips: [],
      webhook_url:
    )
      @method = method.to_s
      @path = path.to_s
      @headers = headers.to_h.deep_stringify_keys
      @params = params.to_h.deep_stringify_keys
      @query = query.to_h.deep_stringify_keys
      @body = body
      @raw_body = raw_body
      @ip = ip
      @ips = Array.wrap(ips).map(&:to_s)
      @webhook_url = webhook_url.to_s
    end

    def item_json
      data = {
        "body" => body,
        "headers" => headers,
        "params" => params,
        "query" => query,
        "method" => method,
        "webhook_url" => webhook_url,
      }
      data["raw_body"] = raw_body if raw_body.present?
      data
    end
  end
end
