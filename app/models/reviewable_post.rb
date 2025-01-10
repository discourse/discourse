# frozen_string_literal: true

class ReviewablePost < Reviewable
  def self.action_aliases
    { reject_and_silence: :reject_and_suspend }
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

    if post.trashed? && guardian.can_recover_post?(post)
      build_action(actions, :approve_and_restore, icon: "check")
    elsif post.hidden?
      build_action(actions, :approve_and_unhide, icon: "check")
    else
      build_action(actions, :approve, icon: "check")
    end

    reject =
      actions.add_bundle(
        "#{id}-reject",
        icon: "xmark",
        label: "reviewables.actions.reject.bundle_title",
      )

    if post.trashed?
      build_action(actions, :reject_and_keep_deleted, icon: "trash-can", bundle: reject)
    elsif guardian.can_delete_post_or_topic?(post)
      build_action(actions, :reject_and_delete, icon: "trash-can", bundle: reject)
    end

    if guardian.can_suspend?(target_created_by)
      build_action(
        actions,
        :reject_and_suspend,
        icon: "ban",
        bundle: reject,
        client_action: "suspend",
      )
      build_action(
        actions,
        :reject_and_silence,
        icon: "microphone-slash",
        bundle: reject,
        client_action: "silence",
      )
    end
  end

  def perform_approve(performed_by, _args)
    successful_transition :approved, recalculate_score: false
  end

  def perform_reject_and_keep_deleted(performed_by, _args)
    successful_transition :rejected, recalculate_score: false
  end

  def perform_approve_and_restore(performed_by, _args)
    PostDestroyer.new(performed_by, post).recover

    successful_transition :approved, recalculate_score: false
  end

  def perform_approve_and_unhide(performed_by, _args)
    post.unhide!

    successful_transition :approved, recalculate_score: false
  end

  def perform_reject_and_delete(performed_by, _args)
    PostDestroyer.new(performed_by, post, reviewable: self).destroy

    successful_transition :rejected, recalculate_score: false
  end

  def perform_reject_and_suspend(performed_by, _args)
    successful_transition :rejected, recalculate_score: false
  end

  private

  def post
    @post ||= (target || Post.with_deleted.find_by(id: target_id))
  end

  def build_action(
    actions,
    id,
    icon:,
    button_class: nil,
    bundle: nil,
    client_action: nil,
    confirm: false
  )
    actions.add(id, bundle: bundle) do |action|
      prefix = "reviewables.actions.#{id}"
      action.icon = icon
      action.button_class = button_class
      action.label = "#{prefix}.title"
      action.description = "#{prefix}.description"
      action.client_action = client_action
      action.confirm_message = "#{prefix}.confirm" if confirm
    end
  end

  def successful_transition(to_state, recalculate_score: true)
    create_result(:success, to_state) do |result|
      result.recalculate_score = recalculate_score
      result.update_flag_stats = { status: to_state, user_ids: [created_by_id] }
    end
  end
end

# == Schema Information
#
# Table name: reviewables
#
#  id                      :bigint           not null, primary key
#  type                    :string           not null
#  status                  :integer          default("pending"), not null
#  created_by_id           :integer          not null
#  reviewable_by_moderator :boolean          default(FALSE), not null
#  category_id             :integer
#  topic_id                :integer
#  score                   :float            default(0.0), not null
#  potential_spam          :boolean          default(FALSE), not null
#  target_id               :integer
#  target_type             :string
#  target_created_by_id    :integer
#  payload                 :json
#  version                 :integer          default(0), not null
#  latest_score            :datetime
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  force_review            :boolean          default(FALSE), not null
#  reject_reason           :text
#  potentially_illegal     :boolean          default(FALSE)
#
# Indexes
#
#  idx_reviewables_score_desc_created_at_desc                  (score,created_at)
#  index_reviewables_on_reviewable_by_group_id                 (reviewable_by_group_id)
#  index_reviewables_on_status_and_created_at                  (status,created_at)
#  index_reviewables_on_status_and_score                       (status,score)
#  index_reviewables_on_status_and_type                        (status,type)
#  index_reviewables_on_target_id_where_post_type_eq_post      (target_id) WHERE ((target_type)::text = 'Post'::text)
#  index_reviewables_on_topic_id_and_status_and_created_by_id  (topic_id,status,created_by_id)
#  index_reviewables_on_type_and_target_id                     (type,target_id) UNIQUE
#
