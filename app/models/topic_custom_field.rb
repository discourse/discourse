# frozen_string_literal: true

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
#  value      :string(1000000)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_topic_custom_fields_on_topic_id_and_name  (topic_id,name)
#  topic_custom_fields_value_key_idx               (value,name) WHERE ((value IS NOT NULL) AND (char_length((value)::text) < 400))
#
