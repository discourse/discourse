class SingleSignOnRecord < ActiveRecord::Base
  belongs_to :user
end

# == Schema Information
#
# Table name: single_sign_on_records
#
#  id                :integer          not null, primary key
#  user_id           :integer          not null
#  external_id       :string(255)      not null
#  last_payload      :text             not null
#  created_at        :datetime
#  updated_at        :datetime
#  external_username :string(255)
#  external_email    :string(255)
#  external_name     :string(255)
#
# Indexes
#
#  index_single_sign_on_records_on_external_id  (external_id) UNIQUE
#
