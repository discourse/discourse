class UserAssociatedAccount < ActiveRecord::Base
  belongs_to :user

  def self.cleanup!
    # This happens when a user starts the registration flow, but doesn't complete it
    # Keeping the rows doesn't cause any technical issue, but we shouldn't store PII unless it's attached to a user
    self.where("user_id IS NULL AND updated_at < ?", 1.day.ago).delete_all
  end
end

# == Schema Information
#
# Table name: user_associated_accounts
#
#  id            :bigint(8)        not null, primary key
#  provider_name :string           not null
#  provider_uid  :string           not null
#  user_id       :integer
#  last_used     :datetime         not null
#  info          :jsonb            not null
#  credentials   :jsonb            not null
#  extra         :jsonb            not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  associated_accounts_provider_uid   (provider_name,provider_uid) UNIQUE
#  associated_accounts_provider_user  (provider_name,user_id) UNIQUE
#
