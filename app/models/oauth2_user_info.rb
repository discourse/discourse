# frozen_string_literal: true

class Oauth2UserInfo < ActiveRecord::Base
  belongs_to :user

end

# == Schema Information
#
# Table name: oauth2_user_infos
#
#  id         :integer          not null, primary key
#  user_id    :integer          not null
#  uid        :string           not null
#  provider   :string           not null
#  email      :string
#  name       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_oauth2_user_infos_on_uid_and_provider      (uid,provider) UNIQUE
#  index_oauth2_user_infos_on_user_id_and_provider  (user_id,provider)
#
