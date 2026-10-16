# frozen_string_literal: true

class ReviewableLiveUser < Reviewable
  include ReviewableActionBuilder

  def self.additional_args(params)
    ReviewableActionBuilder.penalty_args(params)
  end

  def serializer
    ReviewableLiveUserSerializer
  end

  def session
    @session ||= target || Live::Session.find_by(id: target_id)
  end

  def flagged_by_user_ids
    @flagged_by_user_ids ||= reviewable_scores.map(&:user_id)
  end

  # Core assumes flag reviewables hang off a post.
  def post
    nil
  end

  def build_combined_actions(actions, guardian, _args)
    return unless pending?

    agree =
      actions.add_bundle("#{id}-agree", icon: "thumbs-up", label: "reviewables.actions.agree.title")
    build_action(actions, :agree_and_keep, icon: "thumbs-up", bundle: agree)

    if guardian.can_suspend?(target_created_by)
      build_action(
        actions,
        :agree_and_suspend,
        icon: "ban",
        bundle: agree,
        client_action: "suspend",
      )
      build_action(
        actions,
        :agree_and_silence,
        icon: "microphone-slash",
        bundle: agree,
        client_action: "silence",
      )
    end

    build_action(actions, :disagree, icon: "thumbs-down")
    build_action(actions, :ignore, icon: "xmark")
  end

  def perform_agree_and_suspend(performed_by, args)
    result = suspend_user(performed_by:, args:)
    return result unless result.success?

    perform_agree_and_keep(performed_by, args)
  end

  def perform_agree_and_silence(performed_by, args)
    result = silence_user(performed_by:, args:)
    return result unless result.success?

    perform_agree_and_keep(performed_by, args)
  end

  def perform_agree_and_keep(_performed_by, _args)
    create_result(:success, :approved) do |result|
      result.update_flag_stats = { status: :agreed, user_ids: flagged_by_user_ids }
      result.recalculate_score = true
    end
  end

  def perform_disagree(_performed_by, _args)
    create_result(:success, :rejected) do |result|
      result.update_flag_stats = { status: :disagreed, user_ids: flagged_by_user_ids }
      result.recalculate_score = true
    end
  end

  def perform_ignore(_performed_by, _args)
    create_result(:success, :ignored) do |result|
      result.update_flag_stats = { status: :ignored, user_ids: flagged_by_user_ids }
    end
  end

  private

  def dsa_statement_attributes(action_id:, result:, automated_detection:, automated_decision:)
    case action_id
    when :agree_and_suspend
      user = target_created_by.reload

      {
        decision_facts: "The user reported during a live call was suspended.",
        decision_account: "DECISION_ACCOUNT_SUSPENDED",
        content_type: ["CONTENT_TYPE_OTHER"],
        content_type_other: "User account",
        content_date: user.created_at.to_date.iso8601,
        end_date_account_restriction:
          (user.suspended_till.to_date.iso8601 unless user.suspended_forever?),
        automated_detection: "No",
        automated_decision:,
      }.compact
    when :agree_and_silence
      user = target_created_by.reload

      {
        decision_facts:
          "The user reported during a live call had their ability to participate restricted.",
        decision_provision: "DECISION_PROVISION_PARTIAL_SUSPENSION",
        content_type: ["CONTENT_TYPE_OTHER"],
        content_type_other: "User account",
        content_date: user.created_at.to_date.iso8601,
        end_date_service_restriction:
          (user.silenced_till.to_date.iso8601 unless user.silenced_forever?),
        automated_detection: "No",
        automated_decision:,
      }.compact
    end
  end
end

# == Schema Information
#
# Table name: reviewables
#
#  id                      :bigint           not null, primary key
#  force_review            :boolean          default(FALSE), not null
#  latest_score            :datetime
#  payload                 :json
#  potential_spam          :boolean          default(FALSE), not null
#  potentially_illegal     :boolean          default(FALSE)
#  reject_reason           :text
#  reviewable_by_moderator :boolean          default(FALSE), not null
#  score                   :float            default(0.0), not null
#  status                  :integer          default("pending"), not null
#  target_type             :string
#  type                    :string           not null
#  type_source             :string           default("unknown"), not null
#  version                 :integer          default(0), not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  category_id             :integer
#  created_by_id           :integer          not null
#  target_created_by_id    :integer
#  target_id               :integer
#  topic_id                :integer
#
# Indexes
#
#  idx_reviewables_score_desc_created_at_desc                  (score DESC,created_at DESC)
#  index_reviewables_on_reviewable_by_group_id                 (reviewable_by_group_id)
#  index_reviewables_on_status_and_created_at                  (status,created_at)
#  index_reviewables_on_status_and_score                       (status,score)
#  index_reviewables_on_status_and_type                        (status,type)
#  index_reviewables_on_target_created_by_id                   (target_created_by_id)
#  index_reviewables_on_target_id_where_post_type_eq_post      (target_id) WHERE ((target_type)::text = 'Post'::text)
#  index_reviewables_on_topic_id_and_status_and_created_by_id  (topic_id,status,created_by_id)
#  index_reviewables_on_type_and_target_id                     (type,target_id) UNIQUE
#
