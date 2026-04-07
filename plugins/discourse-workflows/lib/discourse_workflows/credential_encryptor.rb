# frozen_string_literal: true

module DiscourseWorkflows
  class CredentialEncryptor
    CURRENT_VERSION = "v1"
    SALT = "discourse-workflows-credentials"
    KEY_LENGTH = 32

    def self.encrypt(hash)
      "#{CURRENT_VERSION}:#{encryptor.encrypt_and_sign(JSON.generate(hash))}"
    end

    def self.decrypt(encrypted_string)
      version, payload = encrypted_string.split(":", 2)

      # Legacy format stored the encrypted blob without a version prefix.
      # Current format is "v1:<encrypted_payload>".
      return JSON.parse(encryptor.decrypt_and_verify(encrypted_string)) unless payload

      JSON.parse(encryptor_for_version(version).decrypt_and_verify(payload))
    end

    def self.encryptor
      encryptor_for_version(CURRENT_VERSION)
    end
    private_class_method :encryptor

    def self.encryptor_for_version(version)
      @encryptors ||= {}
      @encryptors[version] ||= case version
      when "v1"
        key =
          ActiveSupport::KeyGenerator.new(Rails.application.secret_key_base).generate_key(
            SALT,
            KEY_LENGTH,
          )
        ActiveSupport::MessageEncryptor.new(key)
      else
        raise ArgumentError, "Unknown encryption version: #{version}"
      end
    end
    private_class_method :encryptor_for_version
  end
end
