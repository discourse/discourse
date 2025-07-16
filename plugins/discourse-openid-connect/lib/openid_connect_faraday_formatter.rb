# frozen_string_literal: true

require "faraday/logging/formatter"

class OIDCFaradayFormatter < Faraday::Logging::Formatter
  def request(env)
    warn <<~LOG
      OIDC Debugging: request #{env.method.upcase} #{env.url}

      Headers: #{env.request_headers}

      Body: #{env[:body]}
    LOG
  end

  def response(env)
    warn <<~LOG
      OIDC Debugging: response status #{env.status}

      From #{env.method.upcase} #{env.url}

      Headers: #{env.response_headers}

      Body: #{env[:body]}
    LOG
  end
end
