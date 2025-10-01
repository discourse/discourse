# frozen_string_literal: true

class ReviewableFlaggedPost < Reviewable
  include ReviewableActionBuilder

  scope :pending_and_default_visible, -> { pending.default_visible }

  # Penalties are handled by the modal after the action is performed
  def self.action_aliases
    {
      agree_and_keep_hidden: :agree_and_keep,
      agree_and_silence: :agree_and_keep,
      agree_and_suspend: :agree_and_keep,
      agree_and_edit: :agree_and_keep,
      disagree_and_restore: :disagree,
      ignore_and_do_nothing: :ignore,
      delete_user_block: :delete_and_block_user, # legacy name mapped to concern method
    }
  end

  def self.counts_for(posts)
    result = {}

    counts = DB.query(<<~SQL, pending: statuses[:pending])
      SELECT r.target_id AS post_id,
        rs.reviewable_score_type,
        count(*) as total
      FROM reviewables AS r
      INNER JOIN reviewable_scores AS rs ON rs.reviewable_id = r.id
      WHERE r.type = 'ReviewableFlaggedPost'
        AND r.status = :pending
      GROUP BY r.target_id, rs.reviewable_score_type
    SQL

    counts.each do |c|
      result[c.post_id] ||= {}
      result[c.post_id][c.reviewable_score_type] = c.total
    end

    result
  end

  def post
    @post ||= (target || Post.with_deleted.find_by(id: target_id))
  end

  def build_actions(actions, guardian, args)
    return unless pending?
    return if post.blank?
    super
  end

  # TODO (reviewable-refresh): Remove legacy method once new UI fully deployed
  def build_legacy_combined_actions(actions, guardian, args)
    # existing combined logic
    agree_bundle =
      actions.add_bundle("#{id}-agree", icon: "thumbs-up", label: "reviewables.actions.agree.title")

    if !post.user_deleted? && !post.hidden?
      build_action(actions, :agree_and_hide, icon: "far-eye-slash", bundle: agree_bundle)
    end

    if post.hidden?
      build_action(actions, :agree_and_keep_hidden, icon: "thumbs-up", bundle: agree_bundle)
    else
      build_action(actions, :agree_and_keep, icon: "thumbs-up", bundle: agree_bundle)
      build_action(
        actions,
        :agree_and_edit,
        icon: "pencil",
        bundle: agree_bundle,
        client_action: "edit",
      )
    end

    if guardian.can_delete_post_or_topic?(post)
      build_action(actions, :delete_and_agree, icon: "trash-can", bundle: agree_bundle)

      if post.reply_count > 0
        build_action(
          actions,
          :delete_and_agree_replies,
          icon: "trash-can",
          bundle: agree_bundle,
          confirm: true,
        )
      end
    end

    if (potential_spam? || potentially_illegal?) && guardian.can_delete_user?(target_created_by)
      delete_user_actions(actions, agree_bundle)
    end

    if guardian.can_suspend?(target_created_by)
      build_action(
        actions,
        :agree_and_suspend,
        icon: "ban",
        bundle: agree_bundle,
        client_action: "suspend",
      )
      build_action(
        actions,
        :agree_and_silence,
        icon: "microphone-slash",
        bundle: agree_bundle,
        client_action: "silence",
      )
    end

    if post.user_deleted?
      build_action(actions, :agree_and_restore, icon: "far-eye", bundle: agree_bundle)
    end
    if post.hidden?
      build_action(actions, :disagree_and_restore, icon: "thumbs-down")
    else
      build_action(actions, :disagree, icon: "thumbs-down")
    end

    post_visible_or_system_user = !post.hidden? || guardian.user.is_system_user?
    can_delete_post_or_topic = guardian.can_delete_post_or_topic?(post)

    # We must return early in this case otherwise we can end up with a bundle
    # with no associated actions, which is not valid on the client.
    return if !can_delete_post_or_topic && !post_visible_or_system_user

    ignore =
      actions.add_bundle(
        "#{id}-ignore",
        icon: "thumbs-up",
        label: "reviewables.actions.ignore.title",
      )

    if post_visible_or_system_user
      build_action(actions, :ignore_and_do_nothing, icon: "up-right-from-square", bundle: ignore)
    end
    if can_delete_post_or_topic
      build_action(actions, :delete_and_ignore, icon: "trash-can", bundle: ignore)
      if post.reply_count > 0
        build_action(
          actions,
          :delete_and_ignore_replies,
          icon: "trash-can",
          confirm: true,
          bundle: ignore,
        )
      end
    end
  end

  # TODO (reviewable-refresh): Merge into build_actions post rollout.
  def build_new_separated_actions(actions, guardian, args)
    build_post_actions_bundle(actions, guardian)
    build_user_actions_bundle(actions, guardian)
  end

  def perform_ignore(performed_by, args)
    perform_ignore_and_do_nothing(performed_by, args)
  end

  def perform_ignore_and_do_nothing(performed_by, args)
    result =
      create_result(
        :success,
        :ignored,
        performed_by: performed_by,
        args: args,
        flag_status: :ignored,
        recalculate_score: false,
      )
    unassign_topic(performed_by, post)
    result
  end

  def perform_agree_and_keep(performed_by, args)
    result =
      create_result(
        :success,
        :approved,
        performed_by: performed_by,
        args: args,
        flag_status: :agreed,
        recalculate_score: false,
      )
    unassign_topic(performed_by, post)
    result
  end

  def perform_delete_user(performed_by, args)
    # To maintain backwards compatibility, we need to use the old Reviewable status behaviour.
    result = perform_new_delete_user(performed_by, args)
    result.transition_to = :approved if result.success?
    result
  end

  def perform_delete_and_block_user(performed_by, args)
    # To maintain backwards compatibility, we need to use the old Reviewable status behaviour.
    result = perform_new_delete_and_block_user(performed_by, args)
    result.transition_to = :approved if result.success?
    result
  end

  def perform_agree_and_hide(performed_by, args)
    result =
      create_result(
        :success,
        :approved,
        performed_by: performed_by,
        args: args,
        flag_status: :agreed,
        recalculate_score: false,
      ) { |pa| target_post.hide!(pa.post_action_type_id) }
    unassign_topic(performed_by, post)
    result
  end

  def perform_agree_and_restore(performed_by, args)
    result =
      create_result(
        :success,
        :approved,
        performed_by: performed_by,
        args: args,
        flag_status: :agreed,
        recalculate_score: false,
      ) { |_| PostDestroyer.new(performed_by, post).recover }
    unassign_topic(performed_by, post)
    result
  end

  def perform_disagree(performed_by, args)
    post_was_hidden = post.hidden?
    result =
      create_result(
        :success,
        :rejected,
        performed_by: performed_by,
        args: args,
        flag_status: :disagreed,
        recalculate_score: false,
      )
    unassign_topic(performed_by, post)
    notify_poster(performed_by) if post_was_hidden
    result
  end

  def perform_delete_and_ignore(performed_by, args)
    destroyer(performed_by, post).destroy
    result =
      create_result(
        :success,
        :ignored,
        performed_by: performed_by,
        args: args,
        flag_status: :ignored,
        recalculate_score: false,
      )
    unassign_topic(performed_by, post)
    result
  end

  def perform_delete_and_ignore_replies(performed_by, args)
    PostDestroyer.delete_with_replies(performed_by, post, self)
    result =
      create_result(
        :success,
        :ignored,
        performed_by: performed_by,
        args: args,
        flag_status: :ignored,
        recalculate_score: false,
      )
    unassign_topic(performed_by, post)
    result
  end

  def perform_delete_and_agree(performed_by, args)
    destroyer(performed_by, post).destroy
    result =
      create_result(
        :success,
        :approved,
        performed_by: performed_by,
        args: args,
        flag_status: :agreed,
        recalculate_score: false,
      )
    unassign_topic(performed_by, post)
    result
  end

  def perform_delete_and_agree_replies(performed_by, args)
    PostDestroyer.delete_with_replies(performed_by, post, self)
    result =
      create_result(
        :success,
        :approved,
        performed_by: performed_by,
        args: args,
        flag_status: :agreed,
        recalculate_score: false,
      )
    unassign_topic(performed_by, post)
    result
  end

  def unassign_topic(performed_by, post)
    topic = post.topic
    return unless topic && performed_by && SiteSetting.reviewable_claiming != "disabled"
    ReviewableClaimedTopic.where(topic_id: topic.id, automatic: false).delete_all
    topic.reviewables.find_each { |reviewable| reviewable.log_history(:unclaimed, performed_by) }

    user_ids = User.staff.pluck(:id)

    if SiteSetting.enable_category_group_moderation? && topic.category
      user_ids.concat(
        GroupUser
          .joins(
            "INNER JOIN category_moderation_groups ON category_moderation_groups.group_id = group_users.group_id",
          )
          .where("category_moderation_groups.category_id": topic.category.id)
          .distinct
          .pluck(:user_id),
      )
      user_ids.uniq!
    end

    data = { topic_id: topic.id, automatic: false }

    MessageBus.publish("/reviewable_claimed", data, user_ids: user_ids)
  end

  private

  def destroyer(performed_by, post)
    PostDestroyer.new(performed_by, post, reviewable: self)
  end

  def notify_poster(performed_by)
    return unless performed_by.human? && performed_by.staff?

    Jobs.enqueue(
      :send_system_message,
      user_id: post.user_id,
      message_type: "flags_disagreed",
      message_options: {
        flagged_post_raw_content: post.raw,
        url: post.url,
      },
    )
  end
end

# == Schema Information
#
# Table name: reviewables
#
#  id                      :bigint           not null, primary key
#  type                    :string           not null
#  type_source             :string           default("unknown"), not null
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
