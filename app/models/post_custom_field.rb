class PostCustomField < ActiveRecord::Base
  belongs_to :post
end

# == Schema Information
#
# Table name: post_custom_fields
#
#  id         :integer          not null, primary key
#  post_id    :integer          not null
#  name       :string(256)      not null
#  value      :text
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_post_custom_fields_on_name_and_value    (name)
#  index_post_custom_fields_on_post_id_and_name  (post_id,name)
#
