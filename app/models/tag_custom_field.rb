# frozen_string_literal: true

class TagCustomField < ActiveRecord::Base
  include CustomField

  belongs_to :tag
end

# == Schema Information
#
# Table name: tag_custom_fields
#
#  id         :bigint           not null, primary key
#  tag_id     :integer          not null
#  name       :string(256)      not null
#  value      :text
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_tag_custom_fields_on_tag_id_and_name  (tag_id,name)
#
