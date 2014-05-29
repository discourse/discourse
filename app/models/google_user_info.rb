class GoogleUserInfo < ActiveRecord::Base
  belongs_to :user
end

# == Schema Information
#
# Table name: google_user_infos
#
#  id             :integer          not null, primary key
#  user_id        :integer          not null
#  google_user_id :string(255)      not null
#  first_name     :string(255)
#  last_name      :string(255)
#  email          :string(255)
#  gender         :string(255)
#  name           :string(255)
#  link           :string(255)
#  profile_link   :string(255)
#  picture        :string(255)
#  created_at     :datetime
#  updated_at     :datetime
#
# Indexes
#
#  index_google_user_infos_on_google_user_id  (google_user_id) UNIQUE
#  index_google_user_infos_on_user_id         (user_id) UNIQUE
#
