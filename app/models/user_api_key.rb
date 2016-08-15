class UserApiKey < ActiveRecord::Base
  belongs_to :user

  def access
    "#{read ? "r" : ""}#{write ? "w" : ""}#{push ? "p" : ""}"
  end
end

# == Schema Information
#
# Table name: user_api_keys
#
#  id               :integer          not null, primary key
#  user_id          :integer          not null
#  client_id        :string           not null
#  key              :string           not null
#  application_name :string           not null
#  read             :boolean          not null
#  write            :boolean          not null
#  push             :boolean          not null
#  push_url         :string
#  created_at       :datetime
#  updated_at       :datetime
#
# Indexes
#
#  index_user_api_keys_on_client_id  (client_id)
#  index_user_api_keys_on_key        (key) UNIQUE
#  index_user_api_keys_on_user_id    (user_id)
#
