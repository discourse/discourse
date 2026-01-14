# frozen_string_literal: true

class PolicyUser < ActiveRecord::Base
  belongs_to :post_policy
  belongs_to :user

  scope :accepted, -> { where.not(accepted_at: nil).where(revoked_at: nil, expired_at: nil) }
  scope :revoked, -> { where.not(revoked_at: nil).where(accepted_at: nil, expired_at: nil) }
  scope :with_version, ->(version) { where(version: version) }

  def self.add!(user, post_policy)
    post_policy
      .policy_users
      .revoked
      .with_version(post_policy.version)
      .where(user: user)
      .update_all(accepted_at: Time.zone.now)

    self.create!(
      post_policy_id: post_policy.id,
      user_id: user.id,
      accepted_at: Time.zone.now,
      version: post_policy.version,
    )
  end

  def self.remove!(user, post_policy)
    post_policy
      .policy_users
      .accepted
      .with_version(post_policy.version)
      .where(user: user)
      .update_all(revoked_at: Time.zone.now)

    self.create!(
      post_policy_id: post_policy.id,
      user_id: user.id,
      revoked_at: Time.zone.now,
      version: post_policy.version,
    )
  end
end

# == Schema Information
#
# Table name: policy_users
#
#  id             :bigint           not null, primary key
#  post_policy_id :bigint           not null
#  user_id        :integer          not null
#  accepted_at    :datetime
#  revoked_at     :datetime
#  expired_at     :datetime
#  version        :string
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
# Indexes
#
#  index_policy_users_on_post_policy_id_and_user_id  (post_policy_id,user_id)
#
