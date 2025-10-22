# frozen_string_literal: true

class PostPolicy < ActiveRecord::Base
  self.ignored_columns = [
    "group_id", # TODO (sam) (2023-01-01) remove
  ]

  belongs_to :post

  has_many :post_policy_groups, dependent: :destroy
  has_many :groups, through: :post_policy_groups
  has_many :policy_users

  enum :renew_interval, { monthly: 0, quarterly: 1, yearly: 2 }

  before_save :bump_policy

  def accepted_by
    return User.none if !groups.exists?

    User.activated.not_suspended.where(id: accepted_policy_users.select(:user_id)).order(:id)
  end

  def revoked_by
    return User.none if !groups.exists?

    User.activated.not_suspended.where(id: revoked_policy_users.select(:user_id)).order(:id)
  end

  def not_accepted_by
    return User.none if !groups.exists?

    policy_group_users(should_order: false).where.not(id: accepted_policy_users.select(:user_id))
  end

  def emailed_by
    return User.none unless groups.exists?

    emails_enabled_users.where.not(id: accepted_policy_users.select(:user_id))
  end

  def emailed_by_always
    return User.none unless groups.exists?

    emails_enabled_always_users.where.not(id: accepted_policy_users.select(:user_id))
  end

  def emailed_by_when_away
    return User.none unless groups.exists?

    emails_enabled_when_away_users.where.not(id: accepted_policy_users.select(:user_id))
  end

  def add_users_group
    return if add_users_to_group.nil?

    Group.find_by(id: add_users_to_group)
  end

  def accepted_policy_users
    policy_users.accepted.with_version(version)
  end

  private

  def bump_policy
    self.last_bumped_at = Time.current if version_changed?
  end

  def emails_enabled_users
    policy_group_users(should_order: false).joins(:user_option).where(
      "
        (user_options.policy_email_frequency = ?)
        OR (user_options.policy_email_frequency = ? and users.last_seen_at < ?)",
      UserOption.policy_email_frequencies[:always],
      UserOption.policy_email_frequencies[:when_away],
      10.minutes.ago,
    )
  end

  def emails_enabled_always_users
    policy_group_users.joins(:user_option).where(
      "user_options.policy_email_frequency = ?",
      UserOption.policy_email_frequencies[:always],
    )
  end

  def emails_enabled_when_away_users
    policy_group_users
      .joins(:user_option)
      .where(
        "user_options.policy_email_frequency = ?",
        UserOption.policy_email_frequencies[:when_away],
      )
      .where("users.last_seen_at < ?", 10.minutes.ago)
  end

  def revoked_policy_users
    policy_users.revoked.with_version(version)
  end

  def policy_group_users(should_order: true)
    query =
      User
        .activated
        .not_suspended
        .joins(:group_users)
        .joins("JOIN post_policy_groups on post_policy_groups.group_id = group_users.group_id")
        .where("post_policy_groups.post_policy_id = ?", id)
        .distinct

    query = query.order(:id) if should_order
    query
  end
end

# == Schema Information
#
# Table name: post_policies
#
#  id                 :bigint           not null, primary key
#  post_id            :bigint           not null
#  renew_start        :datetime
#  renew_days         :integer
#  next_renew_at      :datetime
#  reminder           :string
#  last_reminded_at   :datetime
#  version            :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  renew_interval     :integer
#  private            :boolean          default(FALSE), not null
#  last_bumped_at     :datetime
#  add_users_to_group :integer
#
