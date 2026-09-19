# frozen_string_literal: true

class UserAuthTokenLog < ActiveRecord::Base
  belongs_to :user
end

# == Schema Information
#
# Table name: user_auth_token_logs
#
#  id                 :integer          not null, primary key
#  action             :string           not null
#  auth_token         :string
#  client_ip          :inet
#  path               :string
#  user_agent         :string
#  created_at         :datetime
#  user_auth_token_id :integer
#  user_id            :integer
#
# Indexes
#
#  index_user_auth_token_logs_on_user_id  (user_id)
#
