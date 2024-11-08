# frozen_string_literal: true

class DiscourseConnectBase
  class ParseError < RuntimeError
  end

  class PayloadParseError < ParseError
  end

  class SignatureError < ParseError
  end

  ACCESSORS = %i[
    add_groups
    admin
    avatar_force_update
    avatar_url
    bio
    card_background_url
    confirmed_2fa
    email
    external_id
    failed
    groups
    locale
    locale_force_update
    location
    logout
    moderator
    name
    no_2fa_methods
    nonce
    prompt
    profile_background_url
    remove_groups
    require_2fa
    require_activation
    return_sso_url
    suppress_welcome_message
    title
    username
    website
  ].freeze

  FIXNUMS = [].freeze

  BOOLS = %i[
    admin
    avatar_force_update
    confirmed_2fa
    failed
    locale_force_update
    logout
    moderator
    no_2fa_methods
    require_2fa
    require_activation
    suppress_welcome_message
  ].freeze

  def self.nonce_expiry_time
    @nonce_expiry_time ||= 30.minutes
  end

  def self.nonce_expiry_time=(v)
    @nonce_expiry_time = v
  end

  def self.used_nonce_expiry_time
    24.hours
  end

  attr_accessor(*ACCESSORS)
  attr_writer :sso_secret, :sso_url

  def self.sso_secret
    raise RuntimeError, "sso_secret not implemented on class, be sure to set it on instance"
  end

  def self.sso_url
    raise RuntimeError, "sso_url not implemented on class, be sure to set it on instance"
  end

  def self.parse(payload, sso_secret = nil, **init_kwargs)
    sso = new(**init_kwargs)
    sso.sso_secret = sso_secret if sso_secret

    parsed = Rack::Utils.parse_query(payload)

    raise PayloadParseError.new(<<~MSG) if parsed["sso"] =~ %r{[^a-zA-Z0-9=\r\n/+]}m
        The SSO field should be Base64 encoded, using only A-Z, a-z, 0-9, +, /, and = characters.
        
        Your input contains characters we don't understand as Base64, see http://en.wikipedia.org/wiki/Base64.
        
        sso: #{parsed["sso"]}
      MSG

    decoded = Base64.decode64(parsed["sso"])
    decoded_hash = Rack::Utils.parse_query(decoded)

    raise SignatureError, <<~MSG if sso.sign(parsed["sso"]) != parsed["sig"]
        Bad signature for payload

        sso: #{parsed["sso"]}
        
        sig: #{parsed["sig"]}
        
        expected sig: #{sso.sign(parsed["sso"])}
        MSG

    ACCESSORS.each do |k|
      val = decoded_hash[k.to_s]
      val = val.to_i if FIXNUMS.include? k
      val = %w[true false].include?(val) ? val == "true" : nil if BOOLS.include? k
      sso.public_send("#{k}=", val)
    end

    decoded_hash.each do |k, v|
      if field = k[/\Acustom\.(.+)\z/, 1]
        sso.custom_fields[field] = v
      end
    end

    sso
  end

  def diagnostics
    DiscourseConnectBase::ACCESSORS.map { |a| "#{a}: #{public_send(a)}" }.join("\n")
  end

  def sso_secret
    @sso_secret || self.class.sso_secret
  end

  def sso_url
    @sso_url || self.class.sso_url
  end

  def custom_fields
    @custom_fields ||= {}
  end

  def self.sign(payload, secret)
    OpenSSL::HMAC.hexdigest("sha256", secret, payload)
  end

  def sign(payload, secret = nil)
    secret = secret || sso_secret
    self.class.sign(payload, secret)
  end

  def to_json
    self.to_h.to_json
  end

  def to_url(base_url = nil)
    base = "#{base_url || sso_url}"
    "#{base}#{base.include?("?") ? "&" : "?"}#{payload}"
  end

  def payload(secret = nil)
    payload = Base64.strict_encode64(unsigned_payload)
    "sso=#{CGI.escape(payload)}&sig=#{sign(payload, secret)}"
  end

  def unsigned_payload
    Rack::Utils.build_query(self.to_h)
  end

  def to_h
    payload = {}

    ACCESSORS.each do |k|
      next if (val = public_send(k)) == nil
      payload[k] = val
    end

    @custom_fields&.each { |k, v| payload["custom.#{k}"] = v.to_s }

    payload
  end
end
