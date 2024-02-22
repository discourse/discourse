# frozen_string_literal: true

class DiscourseConnectProvider < DiscourseConnectBase
  class BlankSecret < RuntimeError
  end

  class BlankReturnUrl < RuntimeError
  end

  class InvalidParameterValueError < RuntimeError
    attr_reader :param
    def initialize(param)
      @param = param
      super("Invalid value for parameter `#{param}`")
    end
  end

  def self.parse(payload, sso_secret = nil, **init_kwargs)
    # We extract the return_sso_url parameter early; we need the URL's host
    # in order to lookup the correct SSO secret in our site settings.
    parsed_payload = Rack::Utils.parse_query(payload)
    return_sso_url = lookup_return_sso_url(parsed_payload)

    raise ParseError if !return_sso_url

    sso_secret ||= lookup_sso_secret(return_sso_url, parsed_payload)

    if sso_secret.blank?
      begin
        host = URI.parse(return_sso_url).host
        Rails.logger.warn(
          "SSO failed; website #{host} is not in the `discourse_connect_provider_secrets` site settings",
        )
      rescue StandardError => e
        # going for StandardError cause URI::Error may not be enough, eg it parses to something not
        # responding to host
        Discourse.warn_exception(
          e,
          message: "SSO failed; invalid or missing return_sso_url in SSO payload",
        )
      end

      raise BlankSecret
    end

    sso = super(payload, sso_secret, **init_kwargs)

    # Do general parameter validation now, after signature-verification has succeeded.
    raise InvalidParameterValueError.new("prompt") if (sso.prompt != nil) && (sso.prompt != "none")

    sso
  end

  def self.lookup_return_sso_url(parsed_payload)
    decoded = Base64.decode64(parsed_payload["sso"])
    decoded_hash = Rack::Utils.parse_query(decoded)
    decoded_hash["return_sso_url"]
  end

  def self.lookup_sso_secret(return_sso_url, parsed_payload)
    return nil unless return_sso_url && SiteSetting.enable_discourse_connect_provider

    return_url_host = URI.parse(return_sso_url).host

    provider_secrets =
      SiteSetting
        .discourse_connect_provider_secrets
        .split("\n")
        .map { |row| row.split("|", 2) }
        .sort_by { |k, _| k }
        .reverse

    first_domain_match = nil

    pair =
      provider_secrets.find do |domain, configured_secret|
        if WildcardDomainChecker.check_domain(domain, return_url_host)
          first_domain_match ||= configured_secret
          sign(parsed_payload["sso"], configured_secret) == parsed_payload["sig"]
        end
      end

    # falls back to a secret which will fail to validate in DiscourseConnectBase
    # this ensures error flow is correct
    pair.present? ? pair[1] : first_domain_match
  end
end
