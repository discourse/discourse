class TopicTag < ActiveRecord::Base
  belongs_to :topic
  belongs_to :tag, counter_cache: "topic_count"
end

# == Schema Information
#
# Table name: topic_tags
#
#  id         :integer          not null, primary key
#  topic_id   :integer          not null
#  tag_id     :integer          not null
#  created_at :datetime
#  updated_at :datetime
#
# Indexes
#
#  index_topic_tags_on_topic_id_and_tag_id  (topic_id,tag_id) UNIQUE
#
