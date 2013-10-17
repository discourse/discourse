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
  end

  # When a post is properly deleted. Well, it's still soft deleted, but it will no longer
  # show up in the topic
  def staff_destroyed
    Post.transaction do

      if @post.topic
        # Update the last post id to the previous post if it exists
        last_post = Post.where("topic_id = ? and id <> ?", @post.topic_id, @post.id).order('created_at desc').limit(1).first
        if last_post.present?
          @post.topic.update_attributes(last_posted_at: last_post.created_at,
                                        last_post_user_id: last_post.user_id,
                                        highest_post_number: last_post.post_number)

          # If the poster doesn't have any other posts in the topic, clear their posted flag
          unless Post.exists?(["topic_id = ? and user_id = ? and id <> ?", @post.topic_id, @post.user_id, @post.id])
            TopicUser.where(topic_id: @post.topic_id, user_id: @post.user_id).update_all 'posted = false'
          end
        end

        # Feature users in the topic
        Jobs.enqueue(:feature_topic_users, topic_id: @post.topic_id, except_post_id: @post.id)
      end

      @post.post_actions.each do |pa|
        pa.trash!(@user)
      end

      f = PostActionType.types.map{|k,v| ["#{k}_count", 0]}
      Post.with_deleted.where(id: @post.id).update_all(Hash[*f.flatten])

      @post.trash!(@user)

      Topic.reset_highest(@post.topic_id) if @post.topic

      @post.update_flagged_posts_count

      # Remove any reply records that point to deleted posts
      post_ids = PostReply.where(reply_id: @post.id).pluck(:post_id)
      PostReply.delete_all reply_id: @post.id

      if post_ids.present?
        Post.where(id: post_ids).each { |p| p.update_column :reply_count, p.replies.count }
      end

      # Remove any notifications that point to this deleted post
      Notification.delete_all topic_id: @post.topic_id, post_number: @post.post_number

      @post.topic.trash!(@user) if @post.topic and @post.post_number == 1

      if @post.topic && @post.topic.category && @post.id == @post.topic.category.latest_post_id
        @post.topic.category.update_latest
      end

      if @post.post_number == 1 && @post.topic && @post.topic.category && @post.topic_id == @post.topic.category.latest_topic_id
        @post.topic.category.update_latest
      end

    end
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
      @post.revise(@user, @post.versions.last.modifications["raw"][0], force_new_version: true)
      @post.update_flagged_posts_count
    end
  end

end
