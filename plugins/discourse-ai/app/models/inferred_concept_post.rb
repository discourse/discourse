# frozen_string_literal: true

class InferredConceptPost < ActiveRecord::Base
  belongs_to :inferred_concept
  belongs_to :post

  validates :inferred_concept_id, presence: true
  validates :post_id, presence: true
  validates :inferred_concept_id, uniqueness: { scope: :post_id }
end

# == Schema Information
#
# Table name: inferred_concept_posts
#
#  inferred_concept_id :bigint
#  post_id             :bigint
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
# Indexes
#
#  index_inferred_concept_posts_on_inferred_concept_id  (inferred_concept_id)
#  index_inferred_concept_posts_uniqueness              (post_id,inferred_concept_id) UNIQUE
#
