class PostOwnerChanger

  def initialize(params)
    @post_ids = params[:post_ids]
    @topic = Topic.with_deleted.find_by(id: params[:topic_id].to_i)
    @new_owner = params[:new_owner]
    @acting_user = params[:acting_user]
    @skip_revision = params[:skip_revision] || false

    raise ArgumentError unless @post_ids && @topic && @new_owner && @acting_user
  end

  def change_owner!
    @post_ids.each do |post_id|
      next unless post = Post.with_deleted.find_by(id: post_id, topic_id: @topic.id)

      if post.is_first_post?
        @topic.user = @new_owner
        @topic.recover! if post.user.nil?
      end

      post.topic = @topic
      post.set_owner(@new_owner, @acting_user, @skip_revision)
      PostAction.remove_act(@new_owner, post, PostActionType.types[:like])

      level = post.is_first_post? ? :watching : :tracking
      TopicUser.change(@new_owner.id, @topic.id, notification_level: NotificationLevels.topic_levels[level])

      if post == @topic.posts.order("post_number DESC").where("NOT hidden AND posts.deleted_at IS NULL").first
        @topic.last_poster = @new_owner
      end

      @topic.update_statistics

      @new_owner.user_stat.update(
        first_post_created_at: @new_owner.reload.posts.order('created_at ASC').first&.created_at
      )

      @topic.save!(validate: false)
    end
  end
end
