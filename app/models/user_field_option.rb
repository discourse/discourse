class UserFieldOption < ActiveRecord::Base
end

# == Schema Information
#
# Table name: user_field_options
#
#  id            :integer          not null, primary key
#  user_field_id :integer          not null
#  value         :string           not null
#  created_at    :datetime
#  updated_at    :datetime
#
