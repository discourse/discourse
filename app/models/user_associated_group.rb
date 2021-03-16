# frozen_string_literal: true

class UserAssociatedGroup < ActiveRecord::Base
  belongs_to :user
end

# == Schema Information
#
# Table name: user_associated_groups
#
#  id              :bigint           not null, primary key
#  provider_name   :string           not null
#  provider_domain :string
#  user_id         :integer          not null
#  group           :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  associated_groups_provider_group       (provider_name,provider_domain,group)
#  associated_groups_provider_user_group  (provider_name,user_id,group) UNIQUE
#
