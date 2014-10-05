class CategoryCustomField < ActiveRecord::Base
  belongs_to :category
end

# == Schema Information
#
# Table name: category_custom_fields
#
#  id          :integer          not null, primary key
#  category_id :integer          not null
#  name        :string(256)      not null
#  value       :text
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_category_custom_fields_on_category_id_and_name  (category_id,name)
#
