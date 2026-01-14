# frozen_string_literal: true

class InferredConceptTopic < ActiveRecord::Base
  belongs_to :inferred_concept
  belongs_to :topic

  validates :inferred_concept_id, presence: true
  validates :topic_id, presence: true
  validates :inferred_concept_id, uniqueness: { scope: :topic_id }
end

# == Schema Information
#
# Table name: inferred_concept_topics
#
#  inferred_concept_id :bigint
#  topic_id            :bigint
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
# Indexes
#
#  index_inferred_concept_topics_on_inferred_concept_id  (inferred_concept_id)
#  index_inferred_concept_topics_uniqueness              (topic_id,inferred_concept_id) UNIQUE
#
