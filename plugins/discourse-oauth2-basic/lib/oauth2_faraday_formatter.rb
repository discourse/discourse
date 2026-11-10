# frozen_string_literal: true

require "faraday/logging/formatter"
require "uri"

class OAuth2LogRedactor
  FILTERED = "[FILTERED]"
  OMITTED = "[OMITTED]"

  SENSITIVE_NAME_PATTERN = /authorization|cookie|secret|token|password|assertion|api[-_]?key|code/i

  def self.headers(headers)
    headers
      .to_h
      .each_with_object({}) do |(name, value), redacted|
        redacted[name] = sensitive_name?(name) ? FILTERED : value
      end
  end

  def self.url(url, sensitive_values: [])
    uri = URI.parse(url.to_s)
    has_userinfo = uri.userinfo.present?
    uri.userinfo = "FILTERED" if has_userinfo
    uri.fragment = FILTERED if uri.fragment.present?

    if uri.query.present?
      uri.query =
        URI.encode_www_form(
          URI
            .decode_www_form(uri.query)
            .map { |name, value| [name, sensitive_name?(name) ? FILTERED : value] },
        )
    end

    redacted_url = uri.to_s
    redacted_url.sub!("FILTERED@", "#{FILTERED}@") if has_userinfo

    sensitive_values
      .compact_blank
      .reduce(redacted_url) do |redacted, sensitive_value|
        raw_value = sensitive_value.to_s
        encoded_value = URI.encode_www_form_component(raw_value)
        redacted.gsub(raw_value, FILTERED).gsub(encoded_value, FILTERED)
      end
  rescue ArgumentError, URI::Error
    FILTERED
  end

  def self.sensitive_name?(name)
    name.to_s.match?(SENSITIVE_NAME_PATTERN)
  end
end

class OAuth2FaradayFormatter < Faraday::Logging::Formatter
  def request(env)
    warn <<~LOG
      OAuth2 Debugging: request #{env.method.upcase} #{OAuth2LogRedactor.url(env.url)}

      Headers:
      #{OAuth2LogRedactor.headers(env.request_headers).to_yaml}

      Body:
      #{OAuth2LogRedactor::OMITTED if env[:body].present?}
    LOG
  end

  def response(env)
    warn <<~LOG
      OAuth2 Debugging: response status #{env.status}

      From #{env.method.upcase} #{OAuth2LogRedactor.url(env.url)}

      Headers:
      #{OAuth2LogRedactor.headers(env.request_headers).to_yaml}

      Body:
      #{OAuth2LogRedactor::OMITTED if env[:body].present?}
    LOG
  end
end
