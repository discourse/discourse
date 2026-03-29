# frozen_string_literal: true

module DiscourseWorkflows
  class CredentialEncryptor
    SALT = "discourse-workflows-credentials"
    KEY_LENGTH = 32

    def self.encrypt(hash)
      encryptor.encrypt_and_sign(JSON.generate(hash))
    end

    def self.decrypt(encrypted_string)
      JSON.parse(encryptor.decrypt_and_verify(encrypted_string))
    end

    def self.encryptor
      key =
        ActiveSupport::KeyGenerator.new(Rails.application.secret_key_base).generate_key(
          SALT,
          KEY_LENGTH,
        )
      ActiveSupport::MessageEncryptor.new(key)
    end
    private_class_method :encryptor
  end
end
