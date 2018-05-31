class UserOpenId < ActiveRecord::Base
  belongs_to :user

  validates_presence_of :email
  validates_presence_of :url
end

# == Schema Information
#
# Table name: user_open_ids
#
#  id         :integer          not null, primary key
#  user_id    :integer          not null
#  email      :string           not null
#  url        :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  active     :boolean          not null
#
# Indexes
#
#  index_user_open_ids_on_url  (url)
#
