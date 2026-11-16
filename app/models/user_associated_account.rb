# frozen_string_literal: true

class UserAssociatedAccount < ActiveRecord::Base
  belongs_to :user
  belongs_to :avatar_upload, class_name: "Upload"
  has_many :upload_references, as: :target, dependent: :destroy

  after_save do
    if saved_change_to_avatar_upload_id?
      UploadReference.ensure_exist!(upload_ids: [avatar_upload_id], target: self)
    end

    if saved_change_to_user_id?
      UserAvatar.clear_associated_account_selection(id, except_user_id: user_id)
    end
  end

  after_destroy { UserAvatar.clear_associated_account_selection(id) }

  def authenticator
    Discourse.enabled_authenticators.find { |authenticator| authenticator.name == provider_name }
  end

  def self.cleanup!
    # This happens when a user starts the registration flow, but doesn't complete it
    # Keeping the rows doesn't cause any technical issue, but we shouldn't store PII unless it's attached to a user
    where("user_id IS NULL AND updated_at < ?", 1.day.ago).find_each(&:destroy!)
  end
end

# == Schema Information
#
# Table name: user_associated_accounts
#
#  id               :bigint           not null, primary key
#  credentials      :jsonb            not null
#  extra            :jsonb            not null
#  info             :jsonb            not null
#  last_used        :datetime         not null
#  provider_name    :string           not null
#  provider_uid     :string           not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  avatar_upload_id :integer
#  user_id          :integer
#
# Indexes
#
#  associated_accounts_provider_uid                    (provider_name,provider_uid) UNIQUE
#  associated_accounts_provider_user                   (provider_name,user_id) UNIQUE
#  index_user_associated_accounts_on_avatar_upload_id  (avatar_upload_id) WHERE (avatar_upload_id IS NOT NULL)
#
