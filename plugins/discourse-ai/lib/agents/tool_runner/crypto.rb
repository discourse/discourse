# frozen_string_literal: true

module DiscourseAi
  module Agents
    class ToolRunner
      # Crypto callbacks are intentionally NOT wrapped in `in_attached_function`.
      # That flag pauses the execution-time budget during *external* waits
      # (HTTP, LLM, sleep). Crypto is pure CPU work — it is the script's own
      # processing time and must count against the runner's timeout.
      module Crypto
        MAX_CRYPTO_INPUT_BYTES = 10_000_000

        def attach_crypto(mini_racer_context)
          # HMAC functions — hex output
          mini_racer_context.attach(
            "_crypto_hmac_sha256_hex",
            ->(key, data) do
              key = key.to_s
              data = data.to_s
              validate_crypto_input!(key, data)
              OpenSSL::HMAC.hexdigest("SHA256", key, data)
            end,
          )

          mini_racer_context.attach(
            "_crypto_hmac_sha1_hex",
            ->(key, data) do
              key = key.to_s
              data = data.to_s
              validate_crypto_input!(key, data)
              OpenSSL::HMAC.hexdigest("SHA1", key, data)
            end,
          )

          # HMAC functions — base64 output
          mini_racer_context.attach(
            "_crypto_hmac_sha256_base64",
            ->(key, data) do
              key = key.to_s
              data = data.to_s
              validate_crypto_input!(key, data)
              Base64.strict_encode64(OpenSSL::HMAC.digest("SHA256", key, data))
            end,
          )

          mini_racer_context.attach(
            "_crypto_hmac_sha1_base64",
            ->(key, data) do
              key = key.to_s
              data = data.to_s
              validate_crypto_input!(key, data)
              Base64.strict_encode64(OpenSSL::HMAC.digest("SHA1", key, data))
            end,
          )

          # Hash functions — hex output
          mini_racer_context.attach(
            "_crypto_sha256_hex",
            ->(data) do
              data = data.to_s
              validate_crypto_input!(data)
              Digest::SHA256.hexdigest(data)
            end,
          )

          mini_racer_context.attach(
            "_crypto_sha1_hex",
            ->(data) do
              data = data.to_s
              validate_crypto_input!(data)
              Digest::SHA1.hexdigest(data)
            end,
          )

          mini_racer_context.attach(
            "_crypto_md5_hex",
            ->(data) do
              data = data.to_s
              validate_crypto_input!(data)
              Digest::MD5.hexdigest(data)
            end,
          )

          # Hash functions — base64 output
          mini_racer_context.attach(
            "_crypto_sha256_base64",
            ->(data) do
              data = data.to_s
              validate_crypto_input!(data)
              Base64.strict_encode64(Digest::SHA256.digest(data))
            end,
          )

          mini_racer_context.attach(
            "_crypto_sha1_base64",
            ->(data) do
              data = data.to_s
              validate_crypto_input!(data)
              Base64.strict_encode64(Digest::SHA1.digest(data))
            end,
          )

          mini_racer_context.attach(
            "_crypto_md5_base64",
            ->(data) do
              data = data.to_s
              validate_crypto_input!(data)
              Base64.strict_encode64(Digest::MD5.digest(data))
            end,
          )

          # Encoding utilities
          mini_racer_context.attach(
            "_crypto_base64_encode",
            ->(text) do
              text = text.to_s
              validate_crypto_input!(text)
              Base64.strict_encode64(text)
            end,
          )

          mini_racer_context.attach(
            "_crypto_base64_decode",
            ->(base64) do
              base64 = base64.to_s
              validate_crypto_input!(base64)
              Base64.decode64(base64)
            end,
          )

          # URL-safe base64 (no padding) — common in JWTs
          mini_racer_context.attach(
            "_crypto_base64_url_encode",
            ->(text) do
              text = text.to_s
              validate_crypto_input!(text)
              Base64.urlsafe_encode64(text, padding: false)
            end,
          )

          mini_racer_context.attach(
            "_crypto_base64_url_decode",
            ->(base64) do
              base64 = base64.to_s
              validate_crypto_input!(base64)
              # Tolerate input with or without padding
              padded = base64 + ("=" * ((4 - (base64.length % 4)) % 4))
              MiniRacer::Binary.new(Base64.urlsafe_decode64(padded))
            end,
          )

          # Uint8Array-returning hash variants — useful when the raw bytes are needed
          # (e.g. feeding into a signer, or concatenating with other binary data).
          mini_racer_context.attach(
            "_crypto_sha256_bytes",
            ->(data) do
              data = data.to_s
              validate_crypto_input!(data)
              MiniRacer::Binary.new(Digest::SHA256.digest(data))
            end,
          )

          mini_racer_context.attach(
            "_crypto_sha1_bytes",
            ->(data) do
              data = data.to_s
              validate_crypto_input!(data)
              MiniRacer::Binary.new(Digest::SHA1.digest(data))
            end,
          )

          mini_racer_context.attach(
            "_crypto_hmac_sha256_bytes",
            ->(key, data) do
              key = key.to_s
              data = data.to_s
              validate_crypto_input!(key, data)
              MiniRacer::Binary.new(OpenSSL::HMAC.digest("SHA256", key, data))
            end,
          )

          mini_racer_context.attach(
            "_crypto_hmac_sha1_bytes",
            ->(key, data) do
              key = key.to_s
              data = data.to_s
              validate_crypto_input!(key, data)
              MiniRacer::Binary.new(OpenSSL::HMAC.digest("SHA1", key, data))
            end,
          )

          # RSA PKCS1v15 signing — accepts PKCS8 or PKCS1 PEM private key
          mini_racer_context.attach(
            "_crypto_sign_rsa_sha256",
            ->(pem_key, data) do
              pem_key = pem_key.to_s
              data = data.to_s
              validate_crypto_input!(pem_key, data)
              key =
                begin
                  OpenSSL::PKey::RSA.new(pem_key)
                rescue OpenSSL::PKey::RSAError => e
                  raise ArgumentError, "Invalid RSA private key: #{e.message}"
                end
              raise ArgumentError, "Expected an RSA private key for signing" unless key.private?
              MiniRacer::Binary.new(key.sign(OpenSSL::Digest.new("SHA256"), data))
            end,
          )

          mini_racer_context.attach(
            "_crypto_sign_rsa_sha1",
            ->(pem_key, data) do
              pem_key = pem_key.to_s
              data = data.to_s
              validate_crypto_input!(pem_key, data)
              key =
                begin
                  OpenSSL::PKey::RSA.new(pem_key)
                rescue OpenSSL::PKey::RSAError => e
                  raise ArgumentError, "Invalid RSA private key: #{e.message}"
                end
              raise ArgumentError, "Expected an RSA private key for signing" unless key.private?
              MiniRacer::Binary.new(key.sign(OpenSSL::Digest.new("SHA1"), data))
            end,
          )

          # Cryptographically secure random bytes — useful for nonces / IVs
          mini_racer_context.attach(
            "_crypto_random_bytes",
            ->(length) do
              length = length.to_i
              if length <= 0 || length > 1024
                raise ArgumentError, "randomBytes length must be between 1 and 1024"
              end
              MiniRacer::Binary.new(SecureRandom.random_bytes(length))
            end,
          )
        end

        private

        def validate_crypto_input!(*inputs)
          inputs.each do |input|
            if input.bytesize > MAX_CRYPTO_INPUT_BYTES
              raise ArgumentError,
                    "Crypto input exceeds maximum size of #{MAX_CRYPTO_INPUT_BYTES} bytes"
            end
          end
        end
      end
    end
  end
end
