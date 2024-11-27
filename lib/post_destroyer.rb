# frozen_string_literal: true

#
# How a post is deleted is affected by who is performing the action.
# this class contains the logic to delete it.
#
class PostDestroyer
  def self.destroy_old_hidden_posts
    Post
      .where(deleted_at: nil, hidden: true)
      .where("hidden_at < ?", 30.days.ago)
      .find_each { |post| PostDestroyer.new(Discourse.system_user, post).destroy }
  end

  def self.destroy_stubs
    context = I18n.t("remove_posts_deleted_by_author")

    # exclude deleted topics and posts that are actively flagged
    Post
      .where(deleted_at: nil, user_deleted: true)
      .where(
        "NOT EXISTS (
            SELECT 1 FROM topics t
            WHERE t.deleted_at IS NOT NULL AND
                  t.id = posts.topic_id
        )",
      )
      .where("updated_at < ?", SiteSetting.delete_removed_posts_after.hours.ago)
      .where(
        "NOT EXISTS (
                  SELECT 1
                  FROM post_actions pa
                  WHERE pa.post_id = posts.id
                    AND pa.deleted_at IS NULL
                    AND pa.deferred_at IS NULL
                    AND pa.post_action_type_id IN (?)
              )",
        PostActionType.notify_flag_type_ids,
      )
      .find_each { |post| PostDestroyer.new(Discourse.system_user, post, context: context).destroy }
  end

  def self.delete_with_replies(performed_by, post, reviewable = nil, defer_reply_flags: true)
    reply_ids = post.reply_ids(Guardian.new(performed_by), only_replies_to_single_post: false)
    replies = Post.where(id: reply_ids.map { |r| r[:id] })
    PostDestroyer.new(performed_by, post, reviewable: reviewable).destroy

    options = { defer_flags: defer_reply_flags }
    if SiteSetting.notify_users_after_responses_deleted_on_flagged_post
      options.merge!({ reviewable: reviewable, notify_responders: true, parent_post: post })
    end
    replies.each { |reply| PostDestroyer.new(performed_by, reply, options).destroy }
  end

  def initialize(user, post, opts = {})
    @user = user
    @post = post
    @topic = post.topic || Topic.with_deleted.find_by(id: @post.topic_id)
    @opts = opts
  end

  def destroy
    delete_removed_posts_after =
      @opts[:delete_removed_posts_after] || SiteSetting.delete_removed_posts_after

    if delete_removed_posts_after < 1 || post_is_reviewable? ||
         Guardian.new(@user).can_moderate_topic?(@topic) || permanent?
      perform_delete
    elsif @user.id == @post.user_id
      mark_for_deletion(delete_removed_posts_after)
    end

    UserActionManager.post_destroyed(@post)

    DiscourseEvent.trigger(:post_destroyed, @post, @opts, @user)
    if WebHook.active_web_hooks(:post_destroyed).exists?
      payload = WebHook.generate_payload(:post, @post)
      WebHook.enqueue_post_hooks(:post_destroyed, @post, payload)
    end
    Jobs.enqueue(:sync_topic_user_bookmarked, topic_id: @topic.id) if @topic

    is_first_post = @post.is_first_post? && @topic
    if is_first_post
      UserProfile.remove_featured_topic_from_all_profiles(@topic)
      UserActionManager.topic_destroyed(@topic)
      DiscourseEvent.trigger(:topic_destroyed, @topic, @user)
      if WebHook.active_web_hooks(:topic_destroyed).exists?
        topic_view = TopicView.new(@topic.id, Discourse.system_user, skip_staff_action: true)
        topic_payload = WebHook.generate_payload(:topic, topic_view, WebHookTopicViewSerializer)
        WebHook.enqueue_topic_hooks(:topic_destroyed, @topic, topic_payload)
      end
      if SiteSetting.tos_topic_id == @topic.id || SiteSetting.privacy_topic_id == @topic.id
        Discourse.clear_urls!
      end
    end
  end

  def recover
    if (post_is_reviewable? || Guardian.new(@user).can_moderate_topic?(@post.topic)) &&
         @post.deleted_at
      staff_recovered
    elsif @user.staff? || @user.id == @post.user_id
      user_recovered
    end

    @topic.update_column(:user_id, Discourse::SYSTEM_USER_ID) if !@topic.user_id
    @topic.recover!(@user) if @post.is_first_post?
    @topic.update_statistics
    Topic.publish_stats_to_clients!(@topic.id, :recovered)

    UserActionManager.post_created(@post)
    DiscourseEvent.trigger(:post_recovered, @post, @opts, @user)
    Jobs.enqueue(:sync_topic_user_bookmarked, topic_id: @topic.id) if @topic
    Jobs.enqueue(:notify_mailing_list_subscribers, post_id: @post.id)

    if @post.is_first_post?
      UserActionManager.topic_created(@topic)
      DiscourseEvent.trigger(:topic_recovered, @topic, @user)
      if @user.id != @post.user_id
        StaffActionLogger.new(@user).log_topic_delete_recover(
          @topic,
          "recover_topic",
          @opts.slice(:context),
        )
      end
      update_imap_sync(@post, false)
      if SiteSetting.tos_topic_id == @topic.id || SiteSetting.privacy_topic_id == @topic.id
        Discourse.clear_urls!
      end
    end
  end

  def staff_recovered
    new_post_attrs = { user_deleted: false }
    new_post_attrs[:user_id] = Discourse::SYSTEM_USER_ID if !@post.user_id
    @post.update_columns(new_post_attrs)
    @post.recover!

    mark_topic_changed

    if @post.topic && !@post.topic.private_message?
      if author = @post.user
        if @post.is_first_post?
          author.user_stat.topic_count += 1
        else
          author.user_stat.post_count += 1
        end
        author.user_stat.save!
      end

      if @post.is_first_post?
        # Update stats of all people who replied
        update_post_counts(:increment)
      end
    end

    # skip also publishing topic stats because they weren't updated yet
    @post.publish_change_to_clients! :recovered, { skip_topic_stats: true }
    TopicTrackingState.publish_recover(@post.topic) if @post.topic && @post.is_first_post?
  end

  # When a post is properly deleted. Well, it's still soft deleted, but it will no longer
  # show up in the topic
  # Permanent option allows to hard delete.
  def perform_delete
    # All posts in the topic must be force deleted if the first is force
    # deleted (except @post which is destroyed by current instance).
    if @topic && @post.is_first_post? && permanent?
      @topic.ordered_posts.with_deleted.reverse_order.find_each do |post|
        PostDestroyer.new(@user, post, @opts).destroy if post.id != @post.id
      end
    end

    Post.transaction do
      permanent? ? @post.destroy! : @post.trash!(@user)
      if @post.topic
        make_previous_post_the_last_one
        mark_topic_changed
        clear_user_posted_flag
      end

      Topic.reset_highest(@post.topic_id)
      trash_public_post_actions
      trash_revisions
      trash_user_actions
      remove_associated_replies
      remove_associated_notifications

      if @user.id != @post.user_id && !@opts[:skip_staff_log]
        if @post.topic && @post.is_first_post?
          StaffActionLogger.new(@user).log_topic_delete_recover(
            @post.topic,
            permanent? ? "delete_topic_permanently" : "delete_topic",
            @opts.slice(:context),
          )
        else
          StaffActionLogger.new(@user).log_post_deletion(
            @post,
            **@opts.slice(:context),
            permanent: permanent?,
          )
        end
      end

      if @topic && @post.is_first_post?
        permanent? ? @topic.destroy! : @topic.trash!(@user)
        PublishedPage.unpublish!(@user, @topic) if @topic.published_page
      end

      TopicLink.where(link_post_id: @post.id).destroy_all
      update_associated_category_latest_topic
      update_user_counts if !permanent?
      TopicUser.update_post_action_cache(post_id: @post.id)

      if permanent?
        if @post.topic && @post.is_first_post?
          UserHistory.where(topic_id: @post.topic.id).update_all(details: "(permanently deleted)")
        end
        UserHistory.where(post_id: @post.id).update_all(details: "(permanently deleted)")
      end

      DB.after_commit do
        if @opts[:reviewable]
          notify_deletion(
            @opts[:reviewable],
            { notify_responders: @opts[:notify_responders], parent_post: @opts[:parent_post] },
          )
          if @post.reviewable_flag &&
               SiteSetting.notify_users_after_responses_deleted_on_flagged_post
            ignore(@post.reviewable_flag)
          end
        elsif reviewable = @post.reviewable_flag
          @opts[:defer_flags] ? ignore(reviewable) : agree(reviewable)
        end
      end
    end

    update_imap_sync(@post, true) if @post.topic&.deleted_at
    feature_users_in_the_topic if @post.topic
    @post.publish_change_to_clients!(permanent? ? :destroyed : :deleted) if @post.topic
    if @post.topic && @post.post_number == 1
      TopicTrackingState.send(permanent? ? :publish_destroy : :publish_delete, @post.topic)
    end
  end

  def permanent?
    @opts[:force_destroy] ||
      (@opts[:permanent] && @user == @post.user && @post.topic.private_message?)
  end

  # When a user 'deletes' their own post. We just change the text.
  def mark_for_deletion(delete_removed_posts_after = SiteSetting.delete_removed_posts_after)
    I18n.with_locale(SiteSetting.default_locale) do
      # don't call revise from within transaction, high risk of deadlock
      key =
        (
          if @post.is_first_post?
            "js.topic.deleted_by_author_simple"
          else
            "js.post.deleted_by_author_simple"
          end
        )
      @post.revise(
        @user,
        { raw: I18n.t(key) },
        force_new_version: true,
        deleting_post: true,
        skip_validations: true,
      )

      Post.transaction do
        @post.update_column(:user_deleted, true)
        @post.topic_links.each(&:destroy)
        @post.topic.update_column(:closed, true) if @post.is_first_post?
      end
    end
  end

  def user_recovered
    return unless @post.user_deleted?

    Post.transaction do
      @post.update_column(:user_deleted, false)
      @post.skip_unique_check = true
      @post.topic.update_column(:closed, false) if @post.is_first_post?
    end

    # has internal transactions, if we nest then there are some very high risk deadlocks
    last_revision = @post.revisions.last
    if last_revision.present? && last_revision.modifications["raw"].present?
      @post.revise(@user, { raw: last_revision.modifications["raw"][0] }, force_new_version: true)
    end
  end

  private

  def post_is_reviewable?
    return true if @user.staff?

    Guardian.new(@user).can_review_topic?(@topic) && Reviewable.exists?(target: @post)
  end

  # we need topics to change if ever a post in them is deleted or created
  # this ensures users relying on this information can keep unread tracking
  # working as desired
  def mark_topic_changed
    # make this as fast as possible, can bypass everything
    DB.exec(<<~SQL, updated_at: Time.now, id: @post.topic_id)
      UPDATE topics
      SET updated_at = :updated_at
      WHERE id = :id
    SQL
  end

  def make_previous_post_the_last_one
    last_post =
      Post
        .select(:created_at, :user_id, :post_number)
        .where("topic_id = ? and id <> ?", @post.topic_id, @post.id)
        .where.not(user_id: nil)
        .where.not(post_type: Post.types[:whisper])
        .order("created_at desc")
        .first

    if last_post.present?
      topic = @post.topic
      topic.last_posted_at = last_post.created_at
      topic.last_post_user_id = last_post.user_id
      topic.highest_post_number = last_post.post_number

      # we go via save here cause we need to run hooks
      topic.save!(validate: false)
    end
  end

  def clear_user_posted_flag
    unless Post.exists?(
             ["topic_id = ? and user_id = ? and id <> ?", @post.topic_id, @post.user_id, @post.id],
           )
      TopicUser.where(topic_id: @post.topic_id, user_id: @post.user_id).update_all "posted = false"
    end
  end

  def feature_users_in_the_topic
    Jobs.enqueue(:feature_topic_users, topic_id: @post.topic_id)
  end

  def post_action_type_view
    @post_action_type_view ||= PostActionTypeView.new
  end

  def trash_public_post_actions
    if public_post_actions = PostAction.publics.where(post_id: @post.id)
      public_post_actions.each { |pa| permanent? ? pa.destroy! : pa.trash!(@user) }

      return if permanent?

      @post.custom_fields["deleted_public_actions"] = public_post_actions.ids
      @post.save_custom_fields

      f = post_action_type_view.public_types.map { |k, _| ["#{k}_count", 0] }
      Post.with_deleted.where(id: @post.id).update_all(Hash[*f.flatten])
    end
  end

  def trash_revisions
    return unless permanent?
    @post.revisions.each(&:destroy!)
  end

  def agree(reviewable)
    notify_deletion(reviewable)
    result = reviewable.perform(@user, :agree_and_keep, post_was_deleted: true)
    reviewable.transition_to(result.transition_to, @user)
  end

  def ignore(reviewable)
    reviewable.perform_ignore_and_do_nothing(@user, post_was_deleted: true)
    reviewable.transition_to(:ignored, @user)
  end

  def notify_deletion(reviewable, options = {})
    return if @post.user.blank?

    allowed_user = @user.human? && @user.staff?
    return unless allowed_user && rs = reviewable.reviewable_scores.order("created_at DESC").first

    # ReviewableScore#types is a superset of PostActionType#flag_types.
    # If the reviewable score type is not on the latter, it means it's not a flag by a user and
    #  must be an automated flag like `needs_approval`. There's no flag reason for these kind of types.
    flag_type = post_action_type_view.flag_types[rs.reviewable_score_type]
    return unless flag_type

    notify_responders = options[:notify_responders]

    Jobs.enqueue(
      :send_system_message,
      user_id: @post.user_id,
      message_type:
        (
          if notify_responders
            "flags_agreed_and_post_deleted_for_responders"
          else
            "flags_agreed_and_post_deleted"
          end
        ),
      message_options: {
        flagged_post_raw_content: notify_responders ? options[:parent_post].raw : @post.raw,
        flagged_post_response_raw_content: @post.raw,
        url: notify_responders ? options[:parent_post].url : @post.url,
        flag_reason:
          I18n.t(
            "flag_reasons#{".responder" if notify_responders}.#{flag_type}",
            locale: SiteSetting.default_locale,
            base_path: Discourse.base_path,
          ),
      },
    )
  end

  def trash_user_actions
    UserAction
      .where(target_post_id: @post.id)
      .each do |ua|
        row = {
          action_type: ua.action_type,
          user_id: ua.user_id,
          acting_user_id: ua.acting_user_id,
          target_topic_id: ua.target_topic_id,
          target_post_id: ua.target_post_id,
        }
        UserAction.remove_action!(row)
      end
  end

  def remove_associated_replies
    post_ids = PostReply.where(reply_post_id: @post.id).pluck(:post_id)

    if post_ids.present?
      PostReply.where(reply_post_id: @post.id).delete_all
      Post.where(id: post_ids).each { |p| p.update_column :reply_count, p.replies.count }
    end
  end

  def remove_associated_notifications
    Notification.where(topic_id: @post.topic_id, post_number: @post.post_number).delete_all
  end

  def update_associated_category_latest_topic
    return unless @post.topic && @post.topic.category
    if @post.id != @post.topic.category.latest_post_id &&
         !(@post.is_first_post? && @post.topic_id == @post.topic.category.latest_topic_id)
      return
    end

    @post.topic.category.update_latest
  end

  def update_user_counts
    author = @post.user

    return unless author

    author.create_user_stat if author.user_stat.nil?

    if @post.created_at == author.user_stat.first_post_created_at
      author.user_stat.update!(
        first_post_created_at: author.posts.order("created_at ASC").first.try(:created_at),
      )
    end

    UserStatCountUpdater.decrement!(@post)

    if @post.created_at == author.last_posted_at
      author.update_column(
        :last_posted_at,
        author.posts.order("created_at DESC").first.try(:created_at),
      )
    end

    if @post.is_first_post? && @post.topic && !@post.topic.private_message?
      # Update stats of all people who replied
      update_post_counts(:decrement)
    end
  end

  def update_imap_sync(post, sync)
    return if !SiteSetting.enable_imap
    incoming = IncomingEmail.find_by(post_id: post.id, topic_id: post.topic_id)
    return if !incoming || !incoming.imap_uid
    incoming.update(imap_sync: sync)
  end

  def update_post_counts(operator)
    counts =
      Post
        .where(post_type: Post.types[:regular], topic_id: @post.topic_id)
        .where("post_number > 1")
        .group(:user_id)
        .count

    counts.each do |user_id, count|
      if user_stat = UserStat.where(user_id: user_id).first
        if operator == :decrement
          UserStatCountUpdater.set!(
            user_stat: user_stat,
            count: user_stat.post_count - count,
            count_column: :post_count,
          )
        else
          UserStatCountUpdater.set!(
            user_stat: user_stat,
            count: user_stat.post_count + count,
            count_column: :post_count,
          )
        end
      end
    end
  end
end
