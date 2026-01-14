# frozen_string_literal: true

class PostPolicyGroup < ActiveRecord::Base
  belongs_to :group
  belongs_to :post_policy
end

# == Schema Information
#
# Table name: post_policy_groups
#
#  id             :bigint           not null, primary key
#  group_id       :integer          not null
#  post_policy_id :bigint           not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
# Indexes
#
#  index_post_policy_groups_on_post_policy_id_and_group_id  (post_policy_id,group_id) UNIQUE
#
