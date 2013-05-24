class GroupUser < ActiveRecord::Base
  belongs_to :group, counter_cache: "user_count"
  belongs_to :user
end

# == Schema Information
#
# Table name: group_users
#
#  id         :integer          not null, primary key
#  group_id   :integer          not null
#  user_id    :integer          not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_group_users_on_group_id_and_user_id  (group_id,user_id) UNIQUE
#

