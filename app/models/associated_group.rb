# frozen_string_literal: true
class AssociatedGroup < ActiveRecord::Base
  has_many :user_associated_groups, dependent: :destroy
  has_many :users, through: :user_associated_groups
  has_many :group_associated_groups, dependent: :destroy
  has_many :groups, through: :group_associated_groups

  def label
    "#{provider_name}:#{name}"
  end

  def self.has_provider?
    Discourse.enabled_authenticators.any? { |a| a.provides_groups? }
  end

  def self.cleanup!
    AssociatedGroup.left_joins(:group_associated_groups, :user_associated_groups)
      .where("group_associated_groups.id IS NULL AND user_associated_groups.id IS NULL")
      .where("last_used < ?", 1.week.ago).delete_all
  end
end

# == Schema Information
#
# Table name: associated_groups
#
#  id            :bigint           not null, primary key
#  name          :string           not null
#  provider_name :string           not null
#  provider_id   :string           not null
#  last_used     :datetime         not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  associated_groups_provider_id  (provider_name,provider_id) UNIQUE
#
