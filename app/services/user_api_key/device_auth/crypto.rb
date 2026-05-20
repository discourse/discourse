# frozen_string_literal: true

class UserApiKey::DeviceAuth::Crypto
  def self.parse_public_key!(value)
    OpenSSL::PKey::RSA.new(value)
  rescue OpenSSL::PKey::RSAError, TypeError
    raise Discourse::InvalidParameters.new(:public_key)
  end

  def self.validate_payload_size!(payload, public_key, padding: nil)
    key_size_bytes = public_key.n.num_bytes
    max_payload_size =
      if padding == "oaep"
        key_size_bytes - 2 * 20 - 2
      else
        key_size_bytes - 11
      end

    if payload.bytesize > max_payload_size
      padding_name = padding == "oaep" ? "OAEP" : "PKCS#1"
      raise Discourse::InvalidParameters.new(
              "Payload too large for #{padding_name} encryption with this key size. " \
                "Maximum: #{max_payload_size} bytes, got: #{payload.bytesize} bytes. " \
                "Try using a shorter nonce or a larger RSA key (minimum 2048-bit recommended).",
            )
    end
  end

  def self.encrypt!(public_key, data, padding: nil)
    padding_mode = padding == "oaep" ? "oaep" : "pkcs1"
    public_key.encrypt(data, { "rsa_padding_mode" => padding_mode })
  rescue OpenSSL::PKey::PKeyError, OpenSSL::PKey::RSAError
    raise Discourse::InvalidParameters.new(:public_key)
  end
end
