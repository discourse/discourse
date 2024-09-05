# frozen_string_literal: true

class Auth::OauthFaradayFormatter < Faraday::Logging::Formatter
  def request(env)
    warn <<~LOG
      OAuth Debugging: request #{env.method.upcase} #{env.url}

      Headers:
      #{env.request_headers}

      Body:
      #{env[:body]}
    LOG
  end

  def response(env)
    warn <<~LOG
      OAuth Debugging: response status #{env.status}

      From #{env.method.upcase} #{env.url}

      Headers:
      #{env.response_headers}

      Body:
      #{env[:body]}
    LOG
  end
end
