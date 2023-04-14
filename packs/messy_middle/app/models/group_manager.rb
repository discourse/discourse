# frozen_string_literal: true

class GroupManager < ActiveRecord::Base
  belongs_to :group
  belongs_to :manager, class_name: "User", foreign_key: :user_id
end

# == Schema Information
#
# Table name: group_managers
#
#  id         :integer          not null, primary key
#  group_id   :integer          not null
#  user_id    :integer          not null
#  created_at :datetime
#  updated_at :datetime
#
# Indexes
#
#  index_group_managers_on_group_id_and_user_id  (group_id,user_id) UNIQUE
#
