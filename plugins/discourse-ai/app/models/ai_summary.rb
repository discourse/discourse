# frozen_string_literal: true

class AiSummary < ActiveRecord::Base
  belongs_to :target, polymorphic: true

  enum :summary_type, { complete: 0, gist: 1 }
  enum :origin, { human: 0, system: 1 }

  LEGACY_UNIQUE_INDEX_NAME = "idx_on_target_id_target_type_summary_type_3355609fbb"

  def self.store!(strategy, llm_model, summary, og_content, human:)
    attributes = {
      target_id: strategy.target.id,
      target_type: strategy.target.class.name,
      algorithm: llm_model.name,
      highest_target_number: strategy.highest_target_number,
      summarized_text: summary,
      original_content_sha: build_sha(og_content.map { |content| content[:id] }.join),
      summary_type: strategy.type,
      origin: human ? origins[:human] : origins[:system],
      locale: strategy.locale,
    }

    strategy.target.with_lock do
      stored_summary = upsert_summary!(attributes)
      remove_superseded_summaries!(strategy, stored_summary)
      stored_summary
    end
  end

  def self.build_sha(joined_ids)
    Digest::SHA256.hexdigest(joined_ids)
  end

  def self.upsert_summary!(attributes)
    upsert_summary(attributes)
  rescue ActiveRecord::RecordNotUnique => error
    raise if !legacy_unique_index_conflict?(error)

    where(attributes.slice(:target_id, :target_type, :summary_type)).delete_all
    upsert_summary(attributes)
  end
  private_class_method :upsert_summary!

  def self.upsert_summary(attributes)
    transaction(requires_new: true) do
      AiSummary
        .upsert(
          attributes,
          unique_by: %i[target_id target_type summary_type locale],
          update_only: %i[
            summarized_text
            original_content_sha
            algorithm
            origin
            highest_target_number
          ],
        )
        .first
        .then { AiSummary.find_by(id: it["id"]) }
    end
  end
  private_class_method :upsert_summary

  def self.legacy_unique_index_conflict?(error)
    cause = error.cause
    return false if !cause.respond_to?(:result)

    constraint_name = cause.result.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)
    constraint_name == LEGACY_UNIQUE_INDEX_NAME
  end
  private_class_method :legacy_unique_index_conflict?

  def self.remove_superseded_summaries!(strategy, stored_summary)
    other_summaries =
      where(target: strategy.target, summary_type: strategy.type)
        .where.not(id: stored_summary.id)
        .select(:id, :locale)
    ids_to_remove =
      other_summaries.filter_map do |candidate|
        if candidate.locale.present? && LocaleNormalizer.is_same?(candidate.locale, strategy.locale)
          candidate.id
        end
      end

    where(id: ids_to_remove).delete_all if ids_to_remove.present?
  end
  private_class_method :remove_superseded_summaries!

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
#  algorithm             :string           not null
#  highest_target_number :integer          default(1), not null
#  locale                :string(20)
#  origin                :integer
#  original_content_sha  :string           not null
#  summarized_text       :string           not null
#  summary_type          :integer          default("complete"), not null
#  target_type           :string           not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  target_id             :integer          not null
#
# Indexes
#
#  idx_ai_summaries_on_target_type_and_locale       (target_id,target_type,summary_type,locale) UNIQUE NULLS NOT DISTINCT
#  index_ai_summaries_on_target_type_and_target_id  (target_type,target_id)
#
