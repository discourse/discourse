# frozen_string_literal: true

module DiscourseMcp
  PROTOCOL_VERSION = "2026-07-28"
  SUPPORTED_PROTOCOL_VERSIONS = [PROTOCOL_VERSION, "2025-11-25"].freeze
  JSONRPC_VERSION = "2.0"
  SERVER_NAME = "discourse"

  class Error < StandardError
    attr_reader :code, :data, :http_status, :headers

    def initialize(message, code: -32_000, data: nil, http_status: 400, headers: {})
      @code = code
      @data = data
      @http_status = http_status
      @headers = headers
      super(message)
    end
  end

  class ToolError < StandardError
  end

  class AuthenticationError < StandardError
    attr_reader :oauth_error

    def initialize(oauth_error = nil)
      @oauth_error = oauth_error
      super("Authorization required")
    end
  end

  class << self
    def registry
      @registry ||= Registry.new
    end

    def reset_registry!
      @registry = Registry.new
      CoreCapabilities.register!
      @registry
    end

    def resource_url
      "#{Discourse.base_url}/mcp"
    end

    def issuer
      Discourse.base_url.delete_suffix("/")
    end

    def protected_resource_metadata_url
      "#{Discourse.base_url}/.well-known/oauth-protected-resource/mcp"
    end
  end
end
