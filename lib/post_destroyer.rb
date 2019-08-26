# frozen_string_literal: true

#
# How a post is deleted is affected by who is performing the action.
# this class contains the logic to delete it.
#
class PostDestroyer

  def self.destroy_old_hidden_posts
    Post.where(deleted_at: nil, hidden: true)
      .where("hidden_at < ?", 30.days.ago)
      .find_each do |post|
      PostDestroyer.new(Discourse.system_user, post).destroy
    end
  end

  def self.destroy_stubs
    context = I18n.t('remove_posts_deleted_by_author')

    # exclude deleted topics and posts that are actively flagged
    Post.where(deleted_at: nil, user_deleted: true)
      .where("NOT EXISTS (
            SELECT 1 FROM topics t
            WHERE t.deleted_at IS NOT NULL AND
                  t.id = posts.topic_id
        )")
      .where("updated_at < ?", SiteSetting.delete_removed_posts_after.hours.ago)
      .where("NOT EXISTS (
                  SELECT 1
                  FROM post_actions pa
                  WHERE pa.post_id = posts.id
                    AND pa.deleted_at IS NULL
                    AND pa.deferred_at IS NULL
                    AND pa.post_action_type_id IN (?)
              )", PostActionType.notify_flag_type_ids)
      .find_each do |post|

      PostDestroyer.new(Discourse.system_user, post, context: context).destroy
    end
  end

  def self.delete_with_replies(performed_by, post, reviewable = nil)
    reply_ids = post.reply_ids(Guardian.new(performed_by), only_replies_to_single_post: false)
    replies = Post.where(id: reply_ids.map { |r| r[:id] })
    PostDestroyer.new(performed_by, post, reviewable: reviewable).destroy
    replies.each { |reply| PostDestroyer.new(performed_by, reply).destroy }
  end

  def initialize(user, post, opts = {})
    @user = user
    @post = post
    @topic = post.topic if post
    @opts = opts
  end

  def destroy
    payload = WebHook.generate_payload(:post, @post) if WebHook.active_web_hooks(:post).exists?
    topic = @post.topic

    if @post.is_first_post? && topic
      topic_view = TopicView.new(topic.id, Discourse.system_user)
      topic_payload = WebHook.generate_payload(:topic, topic_view, WebHookTopicViewSerializer) if WebHook.active_web_hooks(:topic).exists?
    end

    delete_removed_posts_after = @opts[:delete_removed_posts_after] || SiteSetting.delete_removed_posts_after

    if @user.staff? || delete_removed_posts_after < 1
      perform_delete
    elsif @user.id == @post.user_id
      mark_for_deletion(delete_removed_posts_after)
    end

    UserActionManager.post_destroyed(@post)

    DiscourseEvent.trigger(:post_destroyed, @post, @opts, @user)
    WebHook.enqueue_post_hooks(:post_destroyed, @post, payload)

    if @post.is_first_post? && @post.topic
      UserActionManager.topic_destroyed(@post.topic)
      DiscourseEvent.trigger(:topic_destroyed, @post.topic, @user)
      WebHook.enqueue_topic_hooks(:topic_destroyed, @post.topic, topic_payload)
    end
  end

  def recover
    if @user.staff? && @post.deleted_at
      staff_recovered
    elsif @user.staff? || @user.id == @post.user_id
      user_recovered
    end
    topic = Topic.with_deleted.find @post.topic_id
    topic.recover!(@user) if @post.is_first_post?
    topic.update_statistics
    UserActionManager.post_created(@post)
    DiscourseEvent.trigger(:post_recovered, @post, @opts, @user)
    if @post.is_first_post?
      UserActionManager.topic_created(topic)
      DiscourseEvent.trigger(:topic_recovered, topic, @user)
      StaffActionLogger.new(@user).log_topic_delete_recover(topic, "recover_topic", @opts.slice(:context)) if @user.id != @post.user_id
    end
  end

  def staff_recovered
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
        counts = Post.where(post_type: Post.types[:regular], topic_id: @post.topic_id).where('post_number > 1').group(:user_id).count
        counts.each do |user_id, count|
          if user_stat = UserStat.where(user_id: user_id).first
            user_stat.update(post_count: user_stat.post_count + count)
          end
        end
      end
    end

    @post.publish_change_to_clients! :recovered
    TopicTrackingState.publish_recover(@post.topic) if @post.topic && @post.is_first_post?
  end

  # When a post is properly deleted. Well, it's still soft deleted, but it will no longer
  # show up in the topic
  def perform_delete
    Post.transaction do
      @post.trash!(@user)
      if @post.topic
        make_previous_post_the_last_one
        mark_topic_changed
        clear_user_posted_flag
        Topic.reset_highest(@post.topic_id)
      end
      trash_public_post_actions
      trash_user_actions
      remove_associated_replies
      remove_associated_notifications
      if @post.topic && @post.is_first_post?
        StaffActionLogger.new(@user).log_topic_delete_recover(@post.topic, "delete_topic", @opts.slice(:context)) if @user.id != @post.user_id
        @post.topic.trash!(@user)
      elsif @user.id != @post.user_id
        StaffActionLogger.new(@user).log_post_deletion(@post, @opts.slice(:context))
      end
      update_associated_category_latest_topic
      update_user_counts
      TopicUser.update_post_action_cache(post_id: @post.id)

      DB.after_commit do
        if @opts[:reviewable]
          notify_deletion(@opts[:reviewable])
        elsif reviewable = @post.reviewable_flag
          @opts[:defer_flags] ? ignore(reviewable) : agree(reviewable)
        end
      end
    end

    feature_users_in_the_topic if @post.topic
    @post.publish_change_to_clients! :deleted if @post.topic
    TopicTrackingState.publish_delete(@post.topic) if @post.topic && @post.post_number == 1
  end

  # When a user 'deletes' their own post. We just change the text.
  def mark_for_deletion(delete_removed_posts_after = SiteSetting.delete_removed_posts_after)
    I18n.with_locale(SiteSetting.default_locale) do

      # don't call revise from within transaction, high risk of deadlock
      key = @post.is_first_post? ? 'js.topic.deleted_by_author' : 'js.post.deleted_by_author'
      @post.revise(@user,
        { raw: I18n.t(key, count: delete_removed_posts_after) },
        force_new_version: true,
        deleting_post: true
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
    if last_revision.present? && last_revision.modifications['raw'].present?
      @post.revise(@user, { raw: last_revision.modifications["raw"][0] }, force_new_version: true)
    end
  end

  private

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
    last_post = Post
      .select(:created_at, :user_id, :post_number)
      .where("topic_id = ? and id <> ?", @post.topic_id, @post.id)
      .order('created_at desc')
      .limit(1)
      .first

    if last_post.present? && @post.topic.present?
      topic = @post.topic
      topic.last_posted_at = last_post.created_at
      topic.last_post_user_id = last_post.user_id
      topic.highest_post_number = last_post.post_number

      # we go via save here cause we need to run hooks
      topic.save!(validate: false)
    end
  end

  def clear_user_posted_flag
    unless Post.exists?(["topic_id = ? and user_id = ? and id <> ?", @post.topic_id, @post.user_id, @post.id])
      TopicUser.where(topic_id: @post.topic_id, user_id: @post.user_id).update_all 'posted = false'
    end
  end

  def feature_users_in_the_topic
    Jobs.enqueue(:feature_topic_users, topic_id: @post.topic_id)
  end

  def trash_public_post_actions
    if public_post_actions = PostAction.publics.where(post_id: @post.id)
      public_post_actions.each { |pa| pa.trash!(@user) }

      @post.custom_fields["deleted_public_actions"] = public_post_actions.ids
      @post.save_custom_fields

      f = PostActionType.public_types.map { |k, _| ["#{k}_count", 0] }
      Post.with_deleted.where(id: @post.id).update_all(Hash[*f.flatten])
    end
  end

  def agree(reviewable)
    notify_deletion(reviewable)
    result = reviewable.perform(@user, :agree_and_keep, post_was_deleted: true)
    reviewable.transition_to(result.transition_to, @user)
  end

  def ignore(reviewable)
    reviewable.perform_ignore(@user, post_was_deleted: true)
    reviewable.transition_to(:ignored, @user)
  end

  def notify_deletion(reviewable)
    allowed_user = @user.human? && @user.staff?
    return unless allowed_user && rs = reviewable.reviewable_scores.order('created_at DESC').first

    Jobs.enqueue(
      :send_system_message,
      user_id: @post.user_id,
      message_type: :flags_agreed_and_post_deleted,
      message_options: {
        flagged_post_raw_content: @post.raw,
        url: @post.url,
        flag_reason: I18n.t(
          "flag_reasons.#{PostActionType.types[rs.reviewable_score_type]}",
          locale: SiteSetting.default_locale,
          base_path: Discourse.base_path
        )
      }
    )
  end

  def trash_user_actions
    UserAction.where(target_post_id: @post.id).each do |ua|
      row = {
        action_type: ua.action_type,
        user_id: ua.user_id,
        acting_user_id: ua.acting_user_id,
        target_topic_id: ua.target_topic_id,
        target_post_id: ua.target_post_id
      }
      UserAction.remove_action!(row)
    end
  end

  def remove_associated_replies
    post_ids = PostReply.where(reply_id: @post.id).pluck(:post_id)

    if post_ids.present?
      PostReply.where(reply_id: @post.id).delete_all
      Post.where(id: post_ids).each { |p| p.update_column :reply_count, p.replies.count }
    end
  end

  def remove_associated_notifications
    Notification
      .where(topic_id: @post.topic_id, post_number: @post.post_number)
      .delete_all
  end

  def update_associated_category_latest_topic
    return unless @post.topic && @post.topic.category
    return unless @post.id == @post.topic.category.latest_post_id || (@post.is_first_post? && @post.topic_id == @post.topic.category.latest_topic_id)

    @post.topic.category.update_latest
  end

  def update_user_counts
    author = @post.user

    return unless author

    author.create_user_stat if author.user_stat.nil?

    if @post.created_at == author.user_stat.first_post_created_at
      author.user_stat.first_post_created_at = author.posts.order('created_at ASC').first.try(:created_at)
    end

    if @post.topic && !@post.topic.private_message?
      if @post.post_type == Post.types[:regular] && !@post.is_first_post? && !@topic.nil?
        author.user_stat.post_count -= 1
      end
      author.user_stat.topic_count -= 1 if @post.is_first_post?
    end

    # We don't count replies to your own topics in topic_reply_count
    if @topic && author.id != @topic.user_id
      author.user_stat.update_topic_reply_count
    end

    author.user_stat.save!

    if @post.created_at == author.last_posted_at
      author.last_posted_at = author.posts.order('created_at DESC').first.try(:created_at)
      author.save!
    end

    if @post.is_first_post? && @post.topic && !@post.topic.private_message?
      # Update stats of all people who replied
      counts = Post.where(post_type: Post.types[:regular], topic_id: @post.topic_id).where('post_number > 1').group(:user_id).count
      counts.each do |user_id, count|
        if user_stat = UserStat.where(user_id: user_id).first
          user_stat.update(post_count: user_stat.post_count - count)
        end
      end
    end
  end

end
