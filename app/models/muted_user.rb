class MutedUser < ActiveRecord::Base
  belongs_to :user
  belongs_to :muted_user, class_name: 'User'
end

# == Schema Information
#
# Table name: muted_users
#
#  id            :integer          not null, primary key
#  user_id       :integer          not null
#  muted_user_id :integer          not null
#  created_at    :datetime
#  updated_at    :datetime
#
# Indexes
#
#  index_muted_users_on_muted_user_id_and_user_id  (muted_user_id,user_id) UNIQUE
#  index_muted_users_on_user_id_and_muted_user_id  (user_id,muted_user_id) UNIQUE
#
