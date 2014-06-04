#
# How a post is deleted is affected by who is performing the action.
# this class contains the logic to delete it.
#
class PostDestroyer

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

  def initialize(user, post)
    @user, @post = user, post
  end

  def destroy
    if @user.staff?
      staff_destroyed
    elsif @user.id == @post.user_id
      user_destroyed
    end
  end

  def recover
    if @user.staff? && @post.deleted_at
      staff_recovered
    elsif @user.staff? || @user.id == @post.user_id
      user_recovered
    end
    @post.topic.update_statistics
  end

  def staff_recovered
    @post.recover!
    publish("recovered")
  end

  # When a post is properly deleted. Well, it's still soft deleted, but it will no longer
  # show up in the topic
  def staff_destroyed
    Post.transaction do
      @post.trash!(@user)
      if @post.topic
        make_previous_post_the_last_one
        clear_user_posted_flag
        feature_users_in_the_topic
        Topic.reset_highest(@post.topic_id)
      end
      trash_post_actions
      trash_user_actions
      @post.update_flagged_posts_count
      remove_associated_replies
      remove_associated_notifications
      @post.topic.trash!(@user) if @post.topic and @post.post_number == 1
      update_associated_category_latest_topic
    end
    publish("deleted")
  end

  def publish(message)
    # edge case, topic is already destroyed
    return unless @post.topic

    MessageBus.publish("/topic/#{@post.topic_id}",{
                    id: @post.id,
                    post_number: @post.post_number,
                    updated_at: @post.updated_at,
                    type: message
                  },
                  group_ids: @post.topic.secure_group_ids
    )
  end

  # When a user 'deletes' their own post. We just change the text.
  def user_destroyed
    Post.transaction do
      @post.revise(@user, I18n.t('js.post.deleted_by_author', count: SiteSetting.delete_removed_posts_after), force_new_version: true)
      @post.update_column(:user_deleted, true)
      @post.update_flagged_posts_count
      @post.topic_links.each(&:destroy)
    end
  end

  def user_recovered
    Post.transaction do
      @post.update_column(:user_deleted, false)
      @post.skip_unique_check = true
      @post.revise(@user, @post.revisions.last.modifications["raw"][0], force_new_version: true)
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
    Jobs.enqueue(:feature_topic_users, topic_id: @post.topic_id, except_post_id: @post.id)
  end

  def trash_post_actions
    @post.post_actions.each do |pa|
      pa.trash!(@user)
    end

    f = PostActionType.types.map{|k,v| ["#{k}_count", 0]}
    Post.with_deleted.where(id: @post.id).update_all(Hash[*f.flatten])
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
      PostReply.delete_all reply_id: @post.id
      Post.where(id: post_ids).each { |p| p.update_column :reply_count, p.replies.count }
    end
  end

  def remove_associated_notifications
    Notification.delete_all topic_id: @post.topic_id, post_number: @post.post_number
  end

  def update_associated_category_latest_topic
    return unless @post.topic && @post.topic.category
    return unless @post.id == @post.topic.category.latest_post_id || (@post.post_number == 1 && @post.topic_id == @post.topic.category.latest_topic_id)

    @post.topic.category.update_latest
  end

end
