require_dependency 'reviewable'

class ReviewableFlaggedPost < Reviewable

  def self.counts_for(posts)
    result = {}

    counts = DB.query(<<~SQL, pending: Reviewable.statuses[:pending])
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

    agree = actions.add_bundle("#{id}-agree", icon: 'thumbs-up', label: 'reviewables.actions.agree.title')

    build_action(actions, :agree_and_keep, icon: 'thumbs-up', bundle: agree)
    if guardian.can_suspend?(target_created_by)
      build_action(actions, :agree_and_suspend, icon: 'ban', bundle: agree, client_action: 'suspend')
      build_action(actions, :agree_and_silence, icon: 'microphone-slash', bundle: agree, client_action: 'silence')
    end

    if can_delete_spammer = potential_spam? && guardian.can_delete_all_posts?(target_created_by)
      build_action(
        actions,
        :delete_spammer,
        icon: 'exclamation-triangle',
        bundle: agree,
        confirm: true
      )
    end

    if post.user_deleted?
      build_action(actions, :agree_and_restore, icon: 'far-eye', bundle: agree)
    elsif !post.hidden?
      build_action(actions, :agree_and_hide, icon: 'far-eye-slash', bundle: agree)
    end

    if post.hidden?
      build_action(actions, :disagree_and_restore, icon: 'thumbs-down')
    else
      build_action(actions, :disagree, icon: 'thumbs-down')
    end

    build_action(actions, :ignore, icon: 'external-link-alt')

    if guardian.is_staff?
      delete = actions.add_bundle("#{id}-delete", icon: "far-trash-alt", label: "reviewables.actions.delete.title")
      build_action(actions, :delete_and_ignore, icon: 'external-link-alt', bundle: delete)
      if post.reply_count > 0
        build_action(
          actions,
          :delete_and_ignore_replies,
          icon: 'external-link-alt',
          confirm: true,
          bundle: delete
        )
      end
      build_action(actions, :delete_and_agree, icon: 'thumbs-up', bundle: delete)
      if post.reply_count > 0
        build_action(
          actions,
          :delete_and_agree_replies,
          icon: 'external-link-alt',
          bundle: delete,
          confirm: true
        )
      end
    end
  end

  def perform_ignore(performed_by, args)
    actions = PostAction.active
      .where(post_id: target_id)
      .where(post_action_type_id: PostActionType.notify_flag_type_ids)

    actions.each do |action|
      action.deferred_at = Time.zone.now
      action.deferred_by_id = performed_by.id
      # so callback is called
      action.save
      action.add_moderator_post_if_needed(performed_by, :ignored, args[:post_was_deleted])
    end

    if actions.first.present?
      DiscourseEvent.trigger(:flag_reviewed, post)
      DiscourseEvent.trigger(:flag_deferred, actions.first)
    end

    create_result(:success, :ignored) do |result|
      result.update_flag_stats = { status: :ignored, user_ids: actions.map(&:user_id) }
      result.recalculate_score = true
    end
  end

  # Penalties are handled by the modal after the action is performed
  def perform_agree_and_keep(performed_by, args)
    agree(performed_by, args)
  end

  def perform_agree_and_suspend(performed_by, args)
    agree(performed_by, args)
  end

  def perform_agree_and_silence(performed_by, args)
    agree(performed_by, args)
  end

  def perform_delete_spammer(performed_by, args)
    UserDestroyer.new(performed_by).destroy(
      post.user,
      delete_posts: true,
      prepare_for_destroy: true,
      block_email: true,
      block_urls: true,
      block_ip: true,
      delete_as_spammer: true,
      context: "review"
    )

    agree(performed_by, args)
  end

  def perform_agree_and_hide(performed_by, args)
    agree(performed_by, args) do |pa|
      post.hide!(pa.post_action_type_id)
    end
  end

  def perform_agree_and_restore(performed_by, args)
    agree(performed_by, args) do
      PostDestroyer.new(performed_by, post).recover
    end
  end

  def perform_disagree_and_restore(performed_by, args)
    perform_disagree(performed_by, args)
  end

  def perform_disagree(performed_by, args)
    # -1 is the automatic system clear
    action_type_ids =
      if performed_by.id == Discourse::SYSTEM_USER_ID
        PostActionType.auto_action_flag_types.values
      else
        PostActionType.notify_flag_type_ids
      end

    actions = PostAction.active.where(post_id: target_id).where(post_action_type_id: action_type_ids)

    actions.each do |action|
      action.disagreed_at = Time.zone.now
      action.disagreed_by_id = performed_by.id
      # so callback is called
      action.save
      action.add_moderator_post_if_needed(performed_by, :disagreed)
    end

    # reset all cached counters
    cached = {}
    action_type_ids.each do |atid|
      column = "#{PostActionType.types[atid]}_count"
      cached[column] = 0 if ActiveRecord::Base.connection.column_exists?(:posts, column)
    end

    Post.with_deleted.where(id: target_id).update_all(cached)

    if actions.first.present?
      DiscourseEvent.trigger(:flag_reviewed, post)
      DiscourseEvent.trigger(:flag_disagreed, actions.first)
    end

    # Undo hide/silence if applicable
    if post&.hidden?
      post.unhide!
      UserSilencer.unsilence(post.user) if UserSilencer.was_silenced_for?(post)
    end

    create_result(:success, :rejected) do |result|
      result.update_flag_stats = { status: :disagreed, user_ids: actions.map(&:user_id) }
      result.recalculate_score = true
    end
  end

  def perform_delete_and_ignore(performed_by, args)
    result = perform_ignore(performed_by, args)
    PostDestroyer.new(performed_by, post).destroy
    result
  end

  def perform_delete_and_ignore_replies(performed_by, args)
    result = perform_ignore(performed_by, args)

    replies = PostReply.where(post_id: post.id).includes(:reply).map(&:reply)
    PostDestroyer.new(performed_by, post).destroy
    replies.each { |reply| PostDestroyer.new(performed_by, reply).destroy }

    result
  end

  def perform_delete_and_agree(performed_by, args)
    result = agree(performed_by, args)
    PostDestroyer.new(performed_by, post).destroy
    result
  end

  def perform_delete_and_agree_replies(performed_by, args)
    result = agree(performed_by, args)

    replies = PostReply.where(post_id: post.id).includes(:reply).map(&:reply)
    PostDestroyer.new(performed_by, post).destroy
    replies.each { |reply| PostDestroyer.new(performed_by, reply).destroy }

    result
  end

protected

  def agree(performed_by, args)
    actions = PostAction.active
      .where(post_id: target_id)
      .where(post_action_type_id: PostActionType.notify_flag_types.values)

    trigger_spam = false
    actions.each do |action|
      action.agreed_at = Time.zone.now
      action.agreed_by_id = performed_by.id
      # so callback is called
      action.save
      action.add_moderator_post_if_needed(performed_by, :agreed, args[:post_was_deleted])
      trigger_spam = true if action.post_action_type_id == PostActionType.types[:spam]
    end

    DiscourseEvent.trigger(:confirmed_spam_post, post) if trigger_spam

    if actions.first.present?
      DiscourseEvent.trigger(:flag_reviewed, post)
      DiscourseEvent.trigger(:flag_agreed, actions.first)
      yield(actions.first) if block_given?
    end

    create_result(:success, :approved) do |result|
      result.update_flag_stats = { status: :agreed, user_ids: actions.map(&:user_id) }
      result.recalculate_score = true
    end
  end

  def build_action(actions, id, icon:, bundle: nil, client_action: nil, confirm: false)
    actions.add(id, bundle: bundle) do |action|
      prefix = "reviewables.actions.#{id}"
      action.icon = icon
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
#  id                      :bigint(8)        not null, primary key
#  type                    :string           not null
#  status                  :integer          default(0), not null
#  created_by_id           :integer          not null
#  reviewable_by_moderator :boolean          default(FALSE), not null
#  reviewable_by_group_id  :integer
#  claimed_by_id           :integer
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
#
# Indexes
#
#  index_reviewables_on_status_and_created_at                  (status,created_at)
#  index_reviewables_on_status_and_score                       (status,score)
#  index_reviewables_on_status_and_type                        (status,type)
#  index_reviewables_on_topic_id_and_status_and_created_by_id  (topic_id,status,created_by_id)
#  index_reviewables_on_type_and_target_id                     (type,target_id) UNIQUE
#
