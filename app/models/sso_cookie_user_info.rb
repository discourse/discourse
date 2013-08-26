class SsoCookieUserInfo < ActiveRecord::Base
  belongs_to :user
  attr_accessible :sso_id, :user_id
end

# == Schema Information
#
# Table name: sso_cookie_user_infos
#
#  id         :integer          not null, primary key
#  user_id    :integer          not null
#  sso_id     :string(255)      not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_sso_cookie_user_infos_on_sso_id   (sso_id) UNIQUE
#  index_sso_cookie_user_infos_on_user_id  (user_id) UNIQUE
#

