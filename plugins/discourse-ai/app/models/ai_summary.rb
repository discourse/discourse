# frozen_string_literal: true

class AiSummary < ActiveRecord::Base
  # TODO remove this line 01-3-2025
  self.ignored_columns = %i[content_range]

  belongs_to :target, polymorphic: true

  enum :summary_type, { complete: 0, gist: 1 }
  enum :origin, { human: 0, system: 1 }

  def self.store!(strategy, llm_model, summary, og_content, human:)
    content_ids = og_content.map { |c| c[:id] }

    AiSummary
      .upsert(
        {
          target_id: strategy.target.id,
          target_type: strategy.target.class.name,
          algorithm: llm_model.name,
          highest_target_number: strategy.highest_target_number,
          summarized_text: summary,
          original_content_sha: build_sha(content_ids.join),
          summary_type: strategy.type,
          origin: !!human ? origins[:human] : origins[:system],
        },
        unique_by: %i[target_id target_type summary_type],
        update_only: %i[
          summarized_text
          original_content_sha
          algorithm
          origin
          highest_target_number
        ],
      )
      .first
      .then { AiSummary.find_by(id: _1["id"]) }
  end

  def self.build_sha(joined_ids)
    Digest::SHA256.hexdigest(joined_ids)
  end

  def mark_as_outdated
    @outdated = true
  end

  def outdated
    @outdated || false
  end
end

# == Schema Information
#
# Table name: ai_summaries
#
#  id                    :bigint           not null, primary key
#  target_id             :integer          not null
#  target_type           :string           not null
#  summarized_text       :string           not null
#  original_content_sha  :string           not null
#  algorithm             :string           not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  summary_type          :integer          default("complete"), not null
#  origin                :integer
#  highest_target_number :integer          default(1), not null
#
# Indexes
#
#  idx_on_target_id_target_type_summary_type_3355609fbb  (target_id,target_type,summary_type) UNIQUE
#  index_ai_summaries_on_target_type_and_target_id       (target_type,target_id)
#
