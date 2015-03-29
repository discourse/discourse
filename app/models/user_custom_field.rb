class UserCustomField < ActiveRecord::Base
  belongs_to :user
end

# == Schema Information
#
# Table name: user_custom_fields
#
#  id         :integer          not null, primary key
#  user_id    :integer          not null
#  name       :string(256)      not null
#  value      :text
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_user_custom_fields_on_user_id_and_name  (user_id,name)
#
