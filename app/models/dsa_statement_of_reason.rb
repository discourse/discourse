# frozen_string_literal: true
class DsaStatementOfReason < ActiveRecord::Base
  belongs_to :reviewable
  belongs_to :actor, class_name: "User", optional: true
  belongs_to :recipient, class_name: "User", optional: true

  enum :status, { pending: 0, submitted: 1, failed: 2 }

  scope :unclassified, -> { pending.where(classified_at: nil) }
  scope :ready,
        -> do
          pending
            .where.not(classified_at: nil)
            .where("next_attempt_at IS NULL OR next_attempt_at <= ?", Time.zone.now)
        end

  def classify!(community_rule:, category:, actor:)
    can_classify = failed? && actor.admin? || pending? && classified_at.nil? && attempts.zero?
    raise Discourse::InvalidAccess unless can_classify

    mapping = DsaStatementRules.fetch(community_rule)
    if target_type == "Post" &&
         (reviewable.target_type != "Post" || reviewable.target_id != target_id)
      mapping[
        "decision_facts"
      ] = "This item was restricted as part of moderating related content. The moderator identified the following issue in that content: #{mapping["decision_facts"]}"
      mapping[
        "incompatible_content_explanation"
      ] = "The restriction on this item follows from moderation of the related content. #{mapping["incompatible_content_explanation"]}"
    end
    if DsaStatementRules.categories.exclude?(category)
      raise Discourse::InvalidParameters.new(:category)
    end

    update!(
      community_rule: community_rule,
      classified_by_id: actor.id,
      classified_at: Time.zone.now,
      status: :pending,
      error_code: "",
      next_attempt_at: nil,
      payload: payload.merge(mapping).merge("category" => category),
    )
  end

  def retry!
    raise Discourse::InvalidAccess unless failed?
    update!(status: :pending, next_attempt_at: nil, error_code: "")
  end

  def record_submission!(uuid: nil)
    update!(
      status: :submitted,
      submitted_at: Time.zone.now,
      submission_uuid: uuid.to_s,
      error_code: "",
    )
  end

  def begin_attempt!
    update!(
      attempts: attempts + 1,
      next_attempt_at: 30.minutes.from_now,
      api_environment: api_environment.presence || SiteSetting.dsa_api_environment,
    )
  end

  def record_failure!(code:, temporary:, retry_after_seconds: nil)
    delay_seconds = retry_after_seconds || [60 * 2**[attempts, 10].min, 6.hours.to_i].min
    update!(
      status: temporary ? :pending : :failed,
      error_code: code,
      next_attempt_at: temporary ? delay_seconds.clamp(60, 1.day.to_i).seconds.from_now : nil,
    )
  end

  def reverse!
    update!(reversed_at: Time.zone.now)
  end

  def submission_metadata_complete?
    %w[
      puid
      decision_facts
      decision_ground
      incompatible_content_ground
      incompatible_content_explanation
      content_type
      category
      territorial_scope
      content_date
      application_date
      source_type
      automated_detection
      automated_decision
    ].all? { |field| payload[field].present? } &&
      %w[decision_visibility decision_account decision_provision decision_monetary].any? do |field|
        payload[field].present?
      end &&
      (
        !payload.fetch("content_type", []).include?("CONTENT_TYPE_OTHER") ||
          payload["content_type_other"].present?
      )
  end
end

# == Schema Information
#
# Table name: dsa_statement_of_reasons
#
#  id               :bigint           not null, primary key
#  action_name      :string           not null
#  api_environment  :string           default(""), not null
#  attempts         :integer          default(0), not null
#  classified_at    :datetime
#  community_rule   :string           default(""), not null
#  decision_key     :string           not null
#  error_code       :string           default(""), not null
#  next_attempt_at  :datetime
#  payload          :jsonb            not null
#  puid             :string           not null
#  reversed_at      :datetime
#  status           :integer          default("pending"), not null
#  submission_uuid  :string           default(""), not null
#  submitted_at     :datetime
#  target_type      :string           not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  actor_id         :integer
#  classified_by_id :integer
#  recipient_id     :integer
#  reviewable_id    :bigint           not null
#  target_id        :bigint           not null
#
# Indexes
#
#  idx_on_reviewable_id_decision_key_c27ab9a587  (reviewable_id,decision_key)
#  index_dsa_statement_of_reasons_on_puid        (puid) UNIQUE
#  index_dsa_statements_on_decision_and_target   (decision_key,target_type,target_id) UNIQUE
#  index_dsa_statements_pending_delivery         (next_attempt_at,id) WHERE ((status = 0) AND (classified_at IS NOT NULL))
#  index_dsa_statements_unfinished               (reviewable_id) WHERE (((status = 0) AND (classified_at IS NULL)) OR (status = 2))
#
