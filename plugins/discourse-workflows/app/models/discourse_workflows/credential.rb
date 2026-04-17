# frozen_string_literal: true

module DiscourseWorkflows
  class Credential < ActiveRecord::Base
    self.table_name = "discourse_workflows_credentials"

    # Wire-format placeholder sent in JSON responses for password fields.
    # Must remain a string since it round-trips through JSON serialization.
    REDACTED_VALUE = "__REDACTED__"

    validates :name, presence: true, length: { maximum: 128 }
    validates :credential_type, presence: true, length: { maximum: 64 }
    validates :data, presence: true

    def decrypted_data
      CredentialEncryptor.decrypt(data)
    end

    def decrypted_data=(hash)
      self.data = CredentialEncryptor.encrypt(hash)
    end

    def merge_data(incoming)
      original = decrypted_data
      merged =
        original.merge(incoming.stringify_keys) do |_key, orig_val, new_val|
          new_val == REDACTED_VALUE ? orig_val : new_val
        end
      self.decrypted_data = merged
    end
  end
end

# == Schema Information
#
# Table name: discourse_workflows_credentials
#
#  id              :bigint           not null, primary key
#  credential_type :string(64)       not null
#  data            :text             not null
#  name            :string(128)      not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_discourse_workflows_credentials_on_credential_type  (credential_type)
#
