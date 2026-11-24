# frozen_string_literal: true

class InferredConceptPost < ActiveRecord::Base
  belongs_to :inferred_concept
  belongs_to :post

  validates :inferred_concept_id, presence: true
  validates :post_id, presence: true
  validates :inferred_concept_id, uniqueness: { scope: :post_id }
  validates :relevance, numericality: { greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0 }
end

# == Schema Information
#
# Table name: inferred_concept_posts
#
#  digest              :string           default(""), not null
#  primary             :boolean          default(FALSE), not null
#  relevance           :float            default(1.0), not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  inferred_concept_id :bigint
#  post_id             :bigint
#
# Indexes
#
#  index_inferred_concept_posts_on_inferred_concept_id  (inferred_concept_id)
#  index_inferred_concept_posts_uniqueness              (post_id,inferred_concept_id) UNIQUE
#
