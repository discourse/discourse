class TwitterUserInfo < ActiveRecord::Base
  belongs_to :user
end

# == Schema Information
#
# Table name: twitter_user_infos
#
#  id              :integer          not null, primary key
#  user_id         :integer          not null
#  screen_name     :string           not null
#  twitter_user_id :integer          not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  email           :string(1000)
#
# Indexes
#
#  index_twitter_user_infos_on_twitter_user_id  (twitter_user_id) UNIQUE
#  index_twitter_user_infos_on_user_id          (user_id) UNIQUE
#
