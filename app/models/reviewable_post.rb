# frozen_string_literal: true

class ReviewablePost < Reviewable
  include ReviewableActionBuilder

  def self.additional_args(params)
    ReviewableActionBuilder.penalty_args(params)
  end

  def self.queue_for_review_if_possible(post, created_or_edited_by)
    return unless SiteSetting.review_every_post
    return if post.post_type != Post.types[:regular] || post.topic.private_message?
    return if Reviewable.pending.where(target: post).exists?
    if created_or_edited_by.bot? || created_or_edited_by.staff? ||
         created_or_edited_by.has_trust_level?(TrustLevel[4])
      return
    end
    queue_for_review(post)
  end

  def self.queue_for_review(post)
    system_user = Discourse.system_user

    needs_review!(
      target: post,
      topic: post.topic,
      created_by: system_user,
      reviewable_by_moderator: true,
      potential_spam: false,
    ).tap do |reviewable|
      reviewable.add_score(system_user, ReviewableScore.types[:needs_approval], force_review: true)
    end
  end

  def build_actions(actions, guardian, args)
    return unless pending?
    super
  end

  def build_combined_actions(actions, guardian, args)
    if post.trashed? && guardian.can_recover_post?(post)
      build_action(actions, :approve_and_restore, icon: "check")
    elsif post.hidden?
      build_action(actions, :approve_and_unhide, icon: "check")
    else
      build_action(actions, :approve, icon: "check")
    end

    reject =
      actions.add_bundle(
        "#{id}-reject-post",
        icon: "xmark",
        label: "reviewables.actions.reject_post_bundle.title",
      )

    can_penalize = guardian.can_suspend?(target_created_by)

    if post.trashed?
      if can_penalize
        build_action(actions, :reject_and_keep_deleted, icon: "trash-can", bundle: reject)
      else
        actions.add(:reject_and_keep_deleted, bundle: reject) do |a|
          a.icon = "trash-can"
          a.label = "reviewables.actions.reject_and_keep_deleted_standalone.title"
        end
      end
    elsif guardian.can_delete_post_or_topic?(post)
      if can_penalize
        build_action(actions, :reject_and_delete, icon: "trash-can", bundle: reject)
      else
        actions.add(:reject_and_delete, bundle: reject) do |a|
          a.icon = "trash-can"
          a.label = "reviewables.actions.reject_and_delete_standalone.title"
        end
      end
    end

    build_penalty_actions(
      actions,
      bundle: reject,
      silence: :reject_and_silence,
      suspend: :reject_and_suspend,
    )
  end

  def perform_approve(performed_by, _args)
    create_result(:success, :approved, [created_by_id], false)
  end

  def perform_reject_and_keep_deleted(performed_by, _args)
    create_result(:success, :rejected, [created_by_id], false)
  end

  def perform_approve_and_restore(performed_by, _args)
    PostDestroyer.new(performed_by, post).recover

    create_result(:success, :approved, [created_by_id], false)
  end

  def perform_approve_and_unhide(performed_by, _args)
    post.acting_user = performed_by
    post.unhide!

    create_result(:success, :approved, [created_by_id], false)
  end

  def perform_reject_and_delete(performed_by, _args)
    PostDestroyer.new(performed_by, post, reviewable_id: id).destroy

    create_result(:success, :rejected, [created_by_id], false)
  end

  def perform_reject_and_suspend(performed_by, args)
    result = suspend_user(performed_by:, args:)
    return result unless result.success?

    create_result(:success, :rejected, [created_by_id], false)
  end

  def perform_reject_and_silence(performed_by, args)
    result = silence_user(performed_by:, args:)
    return result unless result.success?

    create_result(:success, :rejected, [created_by_id], false)
  end

  private

  def dsa_statement_attributes(action_id:, result:, automated_detection:, automated_decision:)
    case action_id
    when :reject_and_delete, :reject_and_keep_deleted
      {
        decision_facts: "The post was rejected and removed.",
        decision_visibility: ["DECISION_VISIBILITY_CONTENT_REMOVED"],
        content_type: ["CONTENT_TYPE_TEXT"],
        content_date: post.created_at.to_date.iso8601,
        automated_detection:,
        automated_decision:,
      }
    when :reject_and_suspend
      user = target_created_by.reload

      {
        decision_facts: "The author of the rejected post was suspended.",
        decision_account: "DECISION_ACCOUNT_SUSPENDED",
        content_type: ["CONTENT_TYPE_OTHER"],
        content_type_other: "User account",
        content_date: user.created_at.to_date.iso8601,
        end_date_account_restriction:
          (user.suspended_till.to_date.iso8601 unless user.suspended_forever?),
        automated_detection:,
        automated_decision:,
      }.compact
    when :reject_and_silence
      user = target_created_by.reload

      {
        decision_facts:
          "The author of the rejected post had their ability to participate restricted.",
        decision_provision: "DECISION_PROVISION_PARTIAL_SUSPENSION",
        content_type: ["CONTENT_TYPE_OTHER"],
        content_type_other: "User account",
        content_date: user.created_at.to_date.iso8601,
        end_date_service_restriction:
          (user.silenced_till.to_date.iso8601 unless user.silenced_forever?),
        automated_detection:,
        automated_decision:,
      }.compact
    end
  end

  def post
    @post ||= target || Post.with_deleted.find_by(id: target_id)
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
