# frozen_string_literal: true

class NestedTopic < ActiveRecord::Base
  belongs_to :topic

  validates :topic_id, presence: true, uniqueness: true
end

# == Schema Information
#
# Table name: nested_topics
#
#  id                 :bigint           not null, primary key
#  pinned_post_number :integer
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  topic_id           :bigint           not null
#
# Indexes
#
#  index_nested_topics_on_topic_id  (topic_id) UNIQUE
#
