class GoogleUserInfo < ActiveRecord::Base
  belongs_to :user
end

# == Schema Information
#
# Table name: google_user_infos
#
#  id             :integer          not null, primary key
#  user_id        :integer          not null
#  google_user_id :string           not null
#  first_name     :string
#  last_name      :string
#  email          :string
#  gender         :string
#  name           :string
#  link           :string
#  profile_link   :string
#  picture        :string
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
# Indexes
#
#  index_google_user_infos_on_google_user_id  (google_user_id) UNIQUE
#  index_google_user_infos_on_user_id         (user_id) UNIQUE
#
