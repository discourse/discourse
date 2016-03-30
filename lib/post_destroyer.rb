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
    # exclude deleted topics and posts that are actively flagged
    Post.where(deleted_at: nil, user_deleted: true)
        .where("NOT EXISTS (
            SELECT 1 FROM topics t
            WHERE t.deleted_at IS NOT NULL AND
                  t.id = posts.topic_id
        )")
        .where("updated_at < ? AND post_number > 1", SiteSetting.delete_removed_posts_after.hours.ago)
        .where("NOT EXISTS (
                  SELECT 1
                  FROM post_actions pa
                  WHERE pa.post_id = posts.id AND
                        pa.deleted_at IS NULL AND
                        pa.post_action_type_id IN (?)
              )", PostActionType.notify_flag_type_ids)
        .each do |post|
      PostDestroyer.new(Discourse.system_user, post).destroy
    end
  end

  def initialize(user, post, opts={})
    @user = user
    @post = post
    @topic = post.topic if post
    @opts = opts
  end

  def destroy
    if @user.staff? || SiteSetting.delete_removed_posts_after < 1
      perform_delete
    elsif @user.id == @post.user_id
      mark_for_deletion
    end
    DiscourseEvent.trigger(:post_destroyed, @post, @opts, @user)
  end

  def recover
    if @user.staff? && @post.deleted_at
      staff_recovered
    elsif @user.staff? || @user.id == @post.user_id
      user_recovered
    end
    topic = Topic.with_deleted.find @post.topic_id
    topic.recover! if @post.is_first_post?
    topic.update_statistics
    recover_user_actions
    DiscourseEvent.trigger(:post_recovered, @post, @opts, @user)
  end

  def staff_recovered
    @post.recover!
    @post.publish_change_to_clients! :recovered
    TopicTrackingState.publish_recover(@post.topic) if @post.topic && @post.post_number == 1
  end

  # When a post is properly deleted. Well, it's still soft deleted, but it will no longer
  # show up in the topic
  def perform_delete
    Post.transaction do
      @post.trash!(@user)
      if @post.topic
        make_previous_post_the_last_one
        clear_user_posted_flag
        Topic.reset_highest(@post.topic_id)
      end
      trash_public_post_actions
      agree_with_flags
      trash_user_actions
      @post.update_flagged_posts_count
      remove_associated_replies
      remove_associated_notifications
      if @post.topic && @post.is_first_post?
        StaffActionLogger.new(@user).log_topic_deletion(@post.topic, @opts.slice(:context)) if @user.id != @post.user_id
        @post.topic.trash!(@user)
      elsif @user.id != @post.user_id
        StaffActionLogger.new(@user).log_post_deletion(@post, @opts.slice(:context))
      end
      update_associated_category_latest_topic
      update_user_counts
      TopicUser.update_post_action_cache(post_id: @post.id)
    end

    feature_users_in_the_topic if @post.topic
    @post.publish_change_to_clients! :deleted if @post.topic
    TopicTrackingState.publish_delete(@post.topic) if @post.topic && @post.post_number == 1
  end

  # When a user 'deletes' their own post. We just change the text.
  def mark_for_deletion
    I18n.with_locale(SiteSetting.default_locale) do
      Post.transaction do
        @post.revise(@user, { raw: I18n.t('js.post.deleted_by_author', count: SiteSetting.delete_removed_posts_after) }, force_new_version: true)
        @post.update_column(:user_deleted, true)
        @post.update_flagged_posts_count
        @post.topic_links.each(&:destroy)
      end
    end
  end

  def user_recovered
    Post.transaction do
      @post.update_column(:user_deleted, false)
      @post.skip_unique_check = true
      @post.revise(@user, { raw: @post.revisions.last.modifications["raw"][0] }, force_new_version: true)
      @post.update_flagged_posts_count
    end
  end

  private

  def make_previous_post_the_last_one
    last_post = Post.where("topic_id = ? and id <> ?", @post.topic_id, @post.id).order('created_at desc').limit(1).first
    if last_post.present?
      @post.topic.update_attributes(
        last_posted_at: last_post.created_at,
        last_post_user_id: last_post.user_id,
        highest_post_number: last_post.post_number
      )
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
    public_post_actions = PostAction.publics.where(post_id: @post.id)
    public_post_actions.each { |pa| pa.trash!(@user) }

    f = PostActionType.public_types.map { |k, _| ["#{k}_count", 0] }
    Post.with_deleted.where(id: @post.id).update_all(Hash[*f.flatten])
  end

  def agree_with_flags
    PostAction.agree_flags!(@post, @user, delete_post: true)
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

  def recover_user_actions
    # TODO: Use a trash concept for `user_actions` to avoid churn and simplify this?
    UserActionObserver.log_post(@post)
  end

  def remove_associated_replies
    post_ids = PostReply.where(reply_id: @post.id).pluck(:post_id)

    if post_ids.present?
      PostReply.delete_all reply_id: @post.id
      Post.where(id: post_ids).each { |p| p.update_column :reply_count, p.replies.count }
    end
  end

  def remove_associated_notifications
    Notification.delete_all topic_id: @post.topic_id, post_number: @post.post_number
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

    author.user_stat.post_count -= 1
    author.user_stat.topic_count -= 1 if @post.is_first_post?

    # We don't count replies to your own topics
    if @topic && author.id != @topic.user_id
      author.user_stat.update_topic_reply_count
    end

    author.user_stat.save!

    if @post.created_at == author.last_posted_at
      author.last_posted_at = author.posts.order('created_at DESC').first.try(:created_at)
      author.save!
    end
  end

end
