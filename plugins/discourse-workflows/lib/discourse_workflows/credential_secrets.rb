# frozen_string_literal: true

module DiscourseWorkflows
  class CredentialSecrets
    def self.encrypt(value, purpose:)
      encryptor.encrypt_and_sign(value, purpose: purpose)
    end

    def self.decrypt(value, purpose:)
      encryptor.decrypt_and_verify(value, purpose: purpose)
    end

    def self.encryptor
      @encryptors ||= Concurrent::Map.new
      secret = GlobalSetting.safe_secret_key_base
      database = RailsMultisite::ConnectionManagement.current_db
      @encryptors.fetch_or_store([secret, database]) do
        key =
          ActiveSupport::KeyGenerator.new(secret).generate_key(
            "discourse-workflows-credentials:#{database}",
            32,
          )
        ActiveSupport::MessageEncryptor.new(key, cipher: "aes-256-gcm", serializer: JSON)
      end
    end
    private_class_method :encryptor
  end
end
