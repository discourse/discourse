# frozen_string_literal: true

class LinkedTopic < ActiveRecord::Base
  belongs_to :topic
end

# == Schema Information
#
# Table name: linked_topics
#
#  id                :bigint           not null, primary key
#  topic_id          :bigint           not null
#  original_topic_id :bigint           not null
#  sequence          :integer          not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
# Indexes
#
#  index_linked_topics_on_topic_id_and_original_topic_id  (topic_id,original_topic_id) UNIQUE
#  index_linked_topics_on_topic_id_and_sequence           (topic_id,sequence) UNIQUE
#
