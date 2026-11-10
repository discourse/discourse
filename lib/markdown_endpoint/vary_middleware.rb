# frozen_string_literal: true

module MarkdownEndpoint
  class VaryMiddleware
    def initialize(app)
      @app = app
    end

    def call(env)
      status, headers, body = @app.call(env)
      return status, headers, body unless env[RequestConstraint::VARY_ACCEPT_ENV_KEY]

      headers = headers.dup
      vary_key = headers.keys.find { |key| key.casecmp?("Vary") } || "Vary"
      tokens = headers[vary_key].to_s.split(",").map(&:strip).reject(&:blank?)
      tokens << "Accept" unless tokens.any? { |token| token.casecmp?("Accept") }
      headers[vary_key] = tokens.join(", ")

      [status, headers, body]
    end
  end
end
