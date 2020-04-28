# frozen_string_literal: true

class SingleSignOn

  class ParseError < RuntimeError; end

  ACCESSORS = %i{
    add_groups
    admin moderator
    avatar_force_update
    avatar_url
    bio
    card_background_url
    email
    external_id
    groups
    locale
    locale_force_update
    logout
    name
    nonce
    profile_background_url
    remove_groups
    require_activation
    return_sso_url
    suppress_welcome_message
    title
    username
    website
    location
  }

  FIXNUMS = []

  BOOLS = %i{
    admin
    avatar_force_update
    locale_force_update
    logout
    moderator
    require_activation
    suppress_welcome_message
  }

  def self.nonce_expiry_time
    @nonce_expiry_time ||= 10.minutes
  end

  def self.nonce_expiry_time=(v)
    @nonce_expiry_time = v
  end

  attr_accessor(*ACCESSORS)
  attr_writer :sso_secret, :sso_url

  def self.sso_secret
    raise RuntimeError, "sso_secret not implemented on class, be sure to set it on instance"
  end

  def self.sso_url
    raise RuntimeError, "sso_url not implemented on class, be sure to set it on instance"
  end

  def self.parse(payload, sso_secret = nil)
    sso = new
    sso.sso_secret = sso_secret if sso_secret

    parsed = Rack::Utils.parse_query(payload)
    decoded = Base64.decode64(parsed["sso"])
    decoded_hash = Rack::Utils.parse_query(decoded)

    if sso.sign(parsed["sso"]) != parsed["sig"]
      diags = "\n\nsso: #{parsed["sso"]}\n\nsig: #{parsed["sig"]}\n\nexpected sig: #{sso.sign(parsed["sso"])}"
      if parsed["sso"] =~ /[^a-zA-Z0-9=\r\n\/+]/m
        raise ParseError, "The SSO field should be Base64 encoded, using only A-Z, a-z, 0-9, +, /, and = characters. Your input contains characters we don't understand as Base64, see http://en.wikipedia.org/wiki/Base64 #{diags}"
      else
        raise ParseError, "Bad signature for payload #{diags}"
      end
    end

    ACCESSORS.each do |k|
      val = decoded_hash[k.to_s]
      val = val.to_i if FIXNUMS.include? k
      if BOOLS.include? k
        val = ["true", "false"].include?(val) ? val == "true" : nil
      end
      sso.public_send("#{k}=", val)
    end

    decoded_hash.each do |k, v|
      if field = k[/^custom\.(.+)$/, 1]
        sso.custom_fields[field] = v
      end
    end

    sso
  end

  def diagnostics
    SingleSignOn::ACCESSORS.map { |a| "#{a}: #{public_send(a)}" }.join("\n")
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

  def sign(payload, secret = nil)
    secret = secret || sso_secret
    OpenSSL::HMAC.hexdigest("sha256", secret, payload)
  end

  def to_url(base_url = nil)
    base = "#{base_url || sso_url}"
    "#{base}#{base.include?('?') ? '&' : '?'}#{payload}"
  end

  def payload(secret = nil)
    payload = Base64.strict_encode64(unsigned_payload)
    "sso=#{CGI::escape(payload)}&sig=#{sign(payload, secret)}"
  end

  def unsigned_payload
    payload = {}

    ACCESSORS.each do |k|
      next if (val = public_send(k)) == nil
      payload[k] = val
    end

    @custom_fields&.each do |k, v|
      payload["custom.#{k}"] = v.to_s
    end

    Rack::Utils.build_query(payload)
  end

end
