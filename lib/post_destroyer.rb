#
# How a post is deleted is affected by who is performing the action.
# this class contains the logic to delete it.
#
class PostDestroyer

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

  # When a post is properly deleted. Well, it's still soft deleted, but it will no longer
  # show up in the topic
  def staff_destroyed
    Post.transaction do

      # Update the last post id to the previous post if it exists
      last_post = Post.where("topic_id = ? and id <> ?", @post.topic_id, @post.id).order('created_at desc').limit(1).first
      if last_post.present?
        @post.topic.update_attributes(last_posted_at: last_post.created_at,
                                      last_post_user_id: last_post.user_id,
                                      highest_post_number: last_post.post_number)

        # If the poster doesn't have any other posts in the topic, clear their posted flag
        unless Post.exists?(["topic_id = ? and user_id = ? and id <> ?", @post.topic_id, @post.user_id, @post.id])
          TopicUser.update_all 'posted = false', topic_id: @post.topic_id, user_id: @post.user_id
        end
      end

      # Feature users in the topic
      Jobs.enqueue(:feature_topic_users, topic_id: @post.topic_id, except_post_id: @post.id)

      @post.post_actions.map(&:trash!)

      f = PostActionType.types.map{|k,v| ["#{k}_count", 0]}
      Post.with_deleted.update_all(Hash[*f.flatten], id: @post.id)

      @post.trash!

      Topic.reset_highest(@post.topic_id)

      @post.update_flagged_posts_count

      # Remove any reply records that point to deleted posts
      post_ids = PostReply.where(reply_id: @post.id).pluck(:post_id)
      PostReply.delete_all reply_id: @post.id

      if post_ids.present?
        Post.where(id: post_ids).each { |p| p.update_column :reply_count, p.replies.count }
      end

      # Remove any notifications that point to this deleted post
      Notification.delete_all topic_id: @post.topic_id, post_number: @post.post_number

      @post.topic.trash! if @post.post_number == 1
    end
  end

  # When a user 'deletes' their own post. We just change the text.
  def user_destroyed
    Post.transaction do
      @post.revise(@user, I18n.t('js.post.deleted_by_author'), force_new_version: true)
      @post.update_column(:user_deleted, true)
      @post.update_flagged_posts_count
      @post.topic_links.each(&:destroy)
    end
  end

end
