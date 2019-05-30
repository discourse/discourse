# frozen_string_literal: true

class AnonymousUser < ActiveRecord::Base
  belongs_to :user
  belongs_to :master_user, class_name: 'User'
end

# == Schema Information
#
# Table name: anonymous_users
#
#  id             :bigint           not null, primary key
#  user_id        :integer          not null
#  master_user_id :integer          not null
#  active         :boolean          not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
# Indexes
#
#  index_anonymous_users_on_master_user_id  (master_user_id) UNIQUE WHERE active
#  index_anonymous_users_on_user_id         (user_id) UNIQUE
#
