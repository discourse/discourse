class TopicCustomField < ActiveRecord::Base
  belongs_to :topic
end

# == Schema Information
#
# Table name: topic_custom_fields
#
#  id         :integer          not null, primary key
#  topic_id   :integer          not null
#  name       :string(256)      not null
#  value      :text
#  created_at :datetime
#  updated_at :datetime
#
# Indexes
#
#  index_topic_custom_fields_on_topic_id_and_name  (topic_id,name)
#
