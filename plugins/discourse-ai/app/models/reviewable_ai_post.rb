# frozen_string_literal:true

require_dependency "reviewable"

class ReviewableAiPost < Reviewable
  # Penalties are handled by the modal after the action is performed
  def self.action_aliases
    {
      agree_and_keep_hidden: :agree_and_keep,
      agree_and_silence: :agree_and_keep,
      agree_and_suspend: :agree_and_keep,
      disagree_and_restore: :disagree,
    }
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
    PostDestroyer.delete_with_replies(performed_by, post, self)

    perform_ignore(performed_by, args)
  end

  def perform_delete_and_agree_replies(performed_by, args)
    PostDestroyer.delete_with_replies(performed_by, post, self)

    agree
  end

  def perform_delete_user(performed_by, args)
    UserDestroyer.new(performed_by).destroy(post.user, delete_opts)

    agree
  end

  def perform_delete_user_block(performed_by, args)
    delete_options = delete_opts

    delete_options.merge!(block_email: true, block_ip: true) if Rails.env.production?

    UserDestroyer.new(performed_by).destroy(post.user, delete_options)

    agree
  end

  private

  def post
    @post ||= (target || Post.with_deleted.find_by(id: target_id))
  end

  def destroyer(performed_by)
    PostDestroyer.new(performed_by, post, reviewable: self)
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
