# frozen_string_literal: true

module DiscourseWorkflows
  class Credential < ActiveRecord::Base
    self.table_name = "discourse_workflows_credentials"

    validates :name, presence: true, length: { maximum: 128 }
    validates :credential_type, presence: true, length: { maximum: 64 }
    validates :data, presence: true

    def decrypted_data
      CredentialEncryptor.decrypt(data)
    end

    def decrypted_data=(hash)
      self.data = CredentialEncryptor.encrypt(hash)
    end
  end
end
