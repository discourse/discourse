# frozen_string_literal: true

class AllowedPmUser < ActiveRecord::Base
  belongs_to :user
  belongs_to :allowed_pm_user, class_name: "User"
end

# == Schema Information
#
# Table name: allowed_pm_users
#
#  id                 :bigint           not null, primary key
#  user_id            :integer          not null
#  allowed_pm_user_id :integer          not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
# Indexes
#
#  index_allowed_pm_users_on_allowed_pm_user_id_and_user_id  (allowed_pm_user_id,user_id) UNIQUE
#  index_allowed_pm_users_on_user_id_and_allowed_pm_user_id  (user_id,allowed_pm_user_id) UNIQUE
#
