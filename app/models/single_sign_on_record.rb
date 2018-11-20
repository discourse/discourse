class SingleSignOnRecord < ActiveRecord::Base
  belongs_to :user

  validates :external_id, uniqueness: true
end

# == Schema Information
#
# Table name: single_sign_on_records
#
#  id                              :integer          not null, primary key
#  user_id                         :integer          not null
#  external_id                     :string           not null
#  last_payload                    :text             not null
#  created_at                      :datetime         not null
#  updated_at                      :datetime         not null
#  external_username               :string
#  external_email                  :string
#  external_name                   :string
#  external_avatar_url             :string(1000)
#  external_profile_background_url :string
#  external_card_background_url    :string
#
# Indexes
#
#  index_single_sign_on_records_on_external_id  (external_id) UNIQUE
#
