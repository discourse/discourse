# frozen_string_literal: true

require "faraday/logging/formatter"

class OAuth2FaradayFormatter < Faraday::Logging::Formatter
  def request(env)
    warn <<~LOG
      OAuth2 Debugging: request #{env.method.upcase} #{env.url}

      Headers:
      #{env.request_headers.to_yaml}

      Body:
      #{env[:body].to_yaml}
    LOG
  end

  def response(env)
    warn <<~LOG
      OAuth2 Debugging: response status #{env.status}

      From #{env.method.upcase} #{env.url}

      Headers:
      #{env.request_headers.to_yaml}

      Body:
      #{env[:body].to_yaml}
    LOG
  end
end
