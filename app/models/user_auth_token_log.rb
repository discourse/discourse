class UserAuthTokenLog < ActiveRecord::Base
  belongs_to :user
end

# == Schema Information
#
# Table name: user_auth_token_logs
#
#  id                 :integer          not null, primary key
#  action             :string           not null
#  user_auth_token_id :integer
#  user_id            :integer
#  client_ip          :inet
#  user_agent         :string
#  auth_token         :string
#  created_at         :datetime
#  path               :string
#
