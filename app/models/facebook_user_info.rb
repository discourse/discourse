class FacebookUserInfo < ActiveRecord::Base
  belongs_to :user
end

# == Schema Information
#
# Table name: facebook_user_infos
#
#  id               :integer          not null, primary key
#  user_id          :integer          not null
#  facebook_user_id :integer          not null
#  username         :string(255)      not null
#  first_name       :string(255)
#  last_name        :string(255)
#  email            :string(255)
#  gender           :string(255)
#  name             :string(255)
#  link             :string(255)
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_facebook_user_infos_on_facebook_user_id  (facebook_user_id) UNIQUE
#  index_facebook_user_infos_on_user_id           (user_id) UNIQUE
#

