# frozen_string_literal: true

module MarkdownEndpoint
  class RequestConstraint
    VARY_ACCEPT_ENV_KEY = "discourse.markdown_endpoint.vary_accept"

    def initialize(accept: false)
      @accept = accept
    end

    def matches?(request)
      return false unless SiteSetting.enable_markdown_endpoints
      return true unless @accept
      return false if request.path.end_with?(".json", ".rss")

      request.env[VARY_ACCEPT_ENV_KEY] = true
      AcceptHeader.preferred?(request.headers["Accept"])
    end
  end
end
