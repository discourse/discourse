# frozen_string_literal: true

class ReviewablePostVotingComment < Reviewable
  def serializer
    ReviewablePostVotingCommentSerializer
  end

  def self.action_aliases
    {
      agree_and_keep_hidden: :agree_and_delete,
      agree_and_silence: :agree_and_delete,
      agree_and_suspend: :agree_and_delete,
      delete_and_agree: :agree_and_delete,
    }
  end

  def flagged_by_user_ids
    @flagged_by_user_ids ||= reviewable_scores.map(&:user_id)
  end

  def post
    nil
  end

  def comment
    @comment ||= (target || PostVotingComment.with_deleted.find_by(id: target_id))
  end

  def comment_creator
    @comment_creator ||= User.find_by(id: comment.user_id)
  end

  def build_actions(actions, guardian, args)
    return unless pending?
    return if comment.blank?

    agree =
      actions.add_bundle("#{id}-agree", icon: "thumbs-up", label: "reviewables.actions.agree.title")

    if comment.deleted_at?
      build_action(actions, :agree_and_restore, icon: "far-eye", bundle: agree)
      build_action(actions, :agree_and_keep_deleted, icon: "thumbs-up", bundle: agree)
      build_action(actions, :disagree_and_restore, icon: "thumbs-down")
    else
      build_action(actions, :agree_and_delete, icon: "far-eye-slash", bundle: agree)
      build_action(actions, :agree_and_keep_comment, icon: "thumbs-up", bundle: agree)
      build_action(actions, :disagree, icon: "thumbs-down")
    end

    if guardian.can_suspend?(comment_creator)
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

    ignore_bundle = actions.add_bundle("#{id}-ignore", label: "reviewables.actions.ignore.title")

    build_action(actions, :ignore, icon: "up-right-from-square", bundle: ignore_bundle)

    unless comment.deleted_at?
      build_action(actions, :delete_and_agree, icon: "far-trash-can", bundle: ignore_bundle)
    end
  end

  def perform_agree_and_keep_comment(performed_by, args)
    agree
  end

  def perform_agree_and_restore(performed_by, args)
    agree { comment.recover! }
  end

  def perform_agree_and_delete(performed_by, args)
    agree { comment.trash!(performed_by) }
  end

  def perform_disagree_and_restore(performed_by, args)
    disagree { comment.recover! }
  end

  def perform_disagree(performed_by, args)
    disagree
  end

  def perform_ignore(performed_by, args)
    ignore
  end

  def perform_delete_and_ignore(performed_by, args)
    ignore { comment.trash!(performed_by) }
  end

  private

  def agree
    yield if block_given?
    create_result(:success, :approved) do |result|
      result.update_flag_stats = { status: :agreed, user_ids: flagged_by_user_ids }
      result.recalculate_score = true
    end
  end

  def disagree
    yield if block_given?

    UserSilencer.unsilence(comment_creator)

    create_result(:success, :rejected) do |result|
      result.update_flag_stats = { status: :disagreed, user_ids: flagged_by_user_ids }
      result.recalculate_score = true
    end
  end

  def ignore
    yield if block_given?
    create_result(:success, :ignored) do |result|
      result.update_flag_stats = { status: :ignored, user_ids: flagged_by_user_ids }
    end
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
      action.label = "post_voting.comment.#{prefix}.title"
      action.description = "post_voting.comment.#{prefix}.description"
      action.client_action = client_action
      action.confirm_message = "#{prefix}.confirm" if confirm
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
#  type_source             :string           default("unknown"), not null
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
