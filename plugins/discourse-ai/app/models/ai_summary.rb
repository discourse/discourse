# frozen_string_literal: true

class AiSummary < ActiveRecord::Base
  belongs_to :target, polymorphic: true

  before_save :refresh_cooked, if: :needs_cooking?

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
    attributes.merge!(new(attributes).cooked_attributes)

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
            summarized_cooked
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

  def cooked_attributes
    return { summarized_cooked: nil } if !complete? || target_type != "Topic"

    cooking_locale = LocaleNormalizer.normalize_to_i18n(locale)
    cooking_locale = SiteSetting.default_locale if !I18n.locale_available?(cooking_locale)

    I18n.with_locale(cooking_locale) do
      { summarized_cooked: PrettyText.cook(summarized_text, topic_id: target_id) }
    end
  end

  def cook_missing!
    return if !complete? || target_type != "Topic" || !summarized_cooked.nil?

    self
      .class
      .where(
        id:,
        summarized_text:,
        updated_at:,
        locale:,
        target_type:,
        target_id:,
        summary_type:,
        summarized_cooked: nil,
      )
      .update_all(cooked_attributes)
  end

  private

  def needs_cooking?
    return summarized_cooked.present? if !complete? || target_type != "Topic"

    summarized_text_changed? || locale_changed? || target_type_changed? || target_id_changed? ||
      summarized_cooked.nil?
  end

  def refresh_cooked
    assign_attributes(cooked_attributes)
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
#  summarized_cooked     :text
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
#  index_ai_summaries_missing_cooked                (id) WHERE ((summarized_cooked IS NULL) AND (summary_type = 0) AND ((target_type)::text = 'Topic'::text))
#  index_ai_summaries_on_target_type_and_target_id  (target_type,target_id)
#
