# frozen_string_literal: true

class ReviewableOutcome < ActiveRecord::Base
  OUTCOME_SOURCES = %w[human automated].freeze
  LEGAL_BASES = ["illegal content", "tos_violation"].freeze
  RESTRICTION_TYPES = %w[
    visibility_restriction_removal
    visibility_restriction_disable
    account_restriction_suspension
    account_restriction_termination
  ].freeze

  belongs_to :reviewable

  validates :outcome_source, inclusion: { in: OUTCOME_SOURCES }
  validates :legal_basis, inclusion: { in: LEGAL_BASES }
  validate :valid_restriction_types

  before_validation { self.restriction_type = restriction_type.presence&.uniq }

  private

  def valid_restriction_types
    if restriction_type.nil? || restriction_type.all? { |type| RESTRICTION_TYPES.include?(type) }
      return
    end

    errors.add(:restriction_type, :inclusion)
  end
end

# == Schema Information
#
# Table name: reviewable_outcomes
#
#  id               :bigint           not null, primary key
#  legal_basis      :string           not null
#  outcome_source   :string           not null
#  restriction_type :string           is an Array
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  reviewable_id    :bigint           not null
#
# Indexes
#
#  index_reviewable_outcomes_on_reviewable_id_and_id  (reviewable_id,id)
#
