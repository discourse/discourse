# frozen_string_literal: true

class UserCustomField < ActiveRecord::Base
  include CustomField

  belongs_to :user

  scope :searchable,
        -> do
          joins(
            "INNER JOIN user_fields ON user_fields.id = REPLACE(user_custom_fields.name, 'user_field_', '')::INTEGER",
          ).where("user_fields.searchable = TRUE").where(
            "user_custom_fields.name ~ ?",
            '^user_field_\\d+$',
          )
        end
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
