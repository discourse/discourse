class Oauth2UserInfo < ActiveRecord::Base
  belongs_to :user

end

# == Schema Information
#
# Table name: oauth2_user_infos
#
#  id         :integer          not null, primary key
#  user_id    :integer          not null
#  uid        :string(255)      not null
#  provider   :string(255)      not null
#  email      :string(255)
#  name       :string(255)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_oauth2_user_infos_on_uid_and_provider  (uid,provider) UNIQUE
#

