# frozen_string_literal:true

require_dependency "reviewable"

class ReviewableAiPost < Reviewable
  include ReviewableActionBuilder

  def self.additional_args(params)
    ReviewableActionBuilder.penalty_args(params)
  end

  def self.action_aliases
    { agree_and_keep_hidden: :agree_and_keep, disagree_and_restore: :disagree }
  end

  def build_actions(actions, guardian, args)
    return actions if !pending? || post.blank?

    agree =
      actions.add_bundle("#{id}-agree", icon: "thumbs-up", label: "reviewables.actions.agree.title")

    if !post.user_deleted? && !post.hidden?
      build_action(actions, :agree_and_hide, icon: "far-eye-slash", bundle: agree)
    end

    if post.hidden?
      build_action(actions, :agree_and_keep_hidden, icon: "far-eye-slash", bundle: agree)
    else
      build_action(actions, :agree_and_keep, icon: "far-eye", bundle: agree)
    end

    if guardian.can_delete_post_or_topic?(post)
      build_action(actions, :delete_and_agree, icon: "trash-can", bundle: agree)
      if post.reply_count > 0
        build_action(
          actions,
          :delete_and_agree_replies,
          icon: "trash-can",
          bundle: agree,
          confirm: true,
        )
      end
    end

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

    delete_user_actions(actions, agree) if guardian.can_delete_user?(target_created_by)

    build_action(actions, :agree_and_restore, icon: "far-eye", bundle: agree) if post.user_deleted?

    disagree_bundle =
      actions.add_bundle(
        "#{id}-disagree",
        icon: "far-eye",
        label: "reviewables.actions.disagree_bundle.title",
      )

    if post.hidden?
      build_action(actions, :disagree_and_restore, icon: "far-eye", bundle: disagree_bundle)
    else
      build_action(actions, :disagree, icon: "far-eye", bundle: disagree_bundle)
    end

    build_action(actions, :ignore, icon: "xmark", bundle: disagree_bundle)

    if guardian.can_delete_post_or_topic?(post)
      build_action(actions, :delete_and_ignore, icon: "trash-can", bundle: disagree_bundle)
      if post.reply_count > 0
        build_action(
          actions,
          :delete_and_ignore_replies,
          icon: "trash-can",
          confirm: true,
          bundle: disagree_bundle,
        )
      end
    end
  end

  def perform_agree_and_hide(performed_by, args)
    post.hide!(reviewable_scores.first.reviewable_score_type)

    agree
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
    agree
  end

  def perform_agree_and_restore(performed_by, args)
    destroyer(performed_by).recover
    agree
  end

  def perform_disagree(performed_by, args)
    # Undo hide/silence if applicable
    if post.hidden?
      post.acting_user = performed_by
      post.unhide!
    end

    create_result(:success, :rejected) do |result|
      result.update_flag_stats = { status: :disagreed, user_ids: [created_by_id] }
    end
  end

  def perform_ignore(performed_by, args)
    create_result(:success, :ignored) do |result|
      result.update_flag_stats = { status: :ignored, user_ids: [created_by_id] }
    end
  end

  def perform_delete_and_ignore(performed_by, args)
    destroyer(performed_by).destroy

    perform_ignore(performed_by, args)
  end

  def perform_delete_and_agree(performed_by, args)
    destroyer(performed_by).destroy

    agree
  end

  def perform_delete_and_ignore_replies(performed_by, args)
    PostDestroyer.delete_with_replies(performed_by, post, id)

    perform_ignore(performed_by, args)
  end

  def perform_delete_and_agree_replies(performed_by, args)
    PostDestroyer.delete_with_replies(performed_by, post, id)

    agree
  end

  def perform_delete_user(performed_by, args)
    UserDestroyer.new(performed_by).destroy(post.user, delete_opts.merge(reviewable_id: id))

    agree
  end

  def perform_delete_user_block(performed_by, args)
    delete_options = delete_opts.merge(reviewable_id: id)

    delete_options.merge!(block_email: true, block_ip: true) if Rails.env.production?

    UserDestroyer.new(performed_by).destroy(post.user, delete_options)

    agree
  end

  private

  def dsa_statement_attributes(action_id:, result:, automated_detection:, automated_decision:)
    case action_id
    when :agree_and_hide, :agree_and_keep_hidden
      {
        decision_facts:
          "The post was flagged by an automated system and access to it was disabled.",
        decision_visibility: ["DECISION_VISIBILITY_CONTENT_DISABLED"],
        content_type: ["CONTENT_TYPE_TEXT"],
        content_date: post.created_at.to_date.iso8601,
        automated_detection: "Yes",
        automated_decision:,
      }
    when :delete_and_agree, :delete_and_ignore, :delete_and_agree_replies,
         :delete_and_ignore_replies
      {
        decision_facts: "The post was flagged by an automated system and removed.",
        decision_visibility: ["DECISION_VISIBILITY_CONTENT_REMOVED"],
        content_type: ["CONTENT_TYPE_TEXT"],
        content_date: post.created_at.to_date.iso8601,
        automated_detection: "Yes",
        automated_decision:,
      }
    when :agree_and_suspend
      user = post.user.reload

      {
        decision_facts: "The author of a post flagged by an automated system was suspended.",
        decision_account: "DECISION_ACCOUNT_SUSPENDED",
        content_type: ["CONTENT_TYPE_OTHER"],
        content_type_other: "User account",
        content_date: user.created_at.to_date.iso8601,
        end_date_account_restriction:
          (user.suspended_till.to_date.iso8601 unless user.suspended_forever?),
        automated_detection: "Yes",
        automated_decision:,
      }.compact
    when :agree_and_silence
      user = post.user.reload

      {
        decision_facts:
          "The author of a post flagged by an automated system had their ability to participate restricted.",
        decision_provision: "DECISION_PROVISION_PARTIAL_SUSPENSION",
        content_type: ["CONTENT_TYPE_OTHER"],
        content_type_other: "User account",
        content_date: user.created_at.to_date.iso8601,
        end_date_service_restriction:
          (user.silenced_till.to_date.iso8601 unless user.silenced_forever?),
        automated_detection: "Yes",
        automated_decision:,
      }.compact
    when :delete_user, :delete_user_block
      user = post.user

      {
        decision_facts:
          "The author of a post flagged by an automated system had their account deleted.",
        decision_account: "DECISION_ACCOUNT_TERMINATED",
        content_type: ["CONTENT_TYPE_OTHER"],
        content_type_other: "User account",
        content_date: user.created_at.to_date.iso8601,
        automated_detection: "Yes",
        automated_decision:,
      }
    end
  end

  def post
    @post ||= target || Post.with_deleted.find_by(id: target_id)
  end

  def destroyer(performed_by)
    PostDestroyer.new(performed_by, post, reviewable_id: id)
  end

  def agree
    create_result(:success, :approved) do |result|
      result.update_flag_stats = { status: :agreed, user_ids: [created_by_id] }
      result.recalculate_score = true
    end
  end

  def delete_opts
    {
      delete_posts: true,
      prepare_for_destroy: true,
      block_urls: true,
      delete_as_spammer: true,
      context: "review",
    }
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
