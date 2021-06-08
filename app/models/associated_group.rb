# frozen_string_literal: true
class AssociatedGroup < ActiveRecord::Base
  has_many :user_associated_groups, dependent: :destroy
  has_many :users, through: :user_associated_groups
  has_many :group_associated_groups, dependent: :destroy
  has_many :groups, through: :group_associated_groups

  def label
    "#{name}:#{provider_name}#{provider_domain ? ":#{provider_domain}" : ""}"
  end
end

# == Schema Information
#
# Table name: associated_groups
#
#  id              :bigint           not null, primary key
#  name            :string           not null
#  provider_name   :string           not null
#  provider_domain :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  associated_groups_name_provider  (name,provider_name,provider_domain) UNIQUE
#
