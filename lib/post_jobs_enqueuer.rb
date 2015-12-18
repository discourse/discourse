class PostJobsEnqueuer
  def initialize(post, topic, new_topic, opts={})
    @post = post
    @topic = topic
    @new_topic = new_topic
    @opts = opts
  end

  def enqueue_jobs
    # We need to enqueue jobs after the transaction.
    # Otherwise they might begin before the data has been comitted.
    enqueue_post_alerts unless @opts[:import_mode]
    feature_topic_users unless @opts[:import_mode]
    trigger_post_post_process

    unless skip_after_create?
      after_post_create
      after_topic_create
    end
  end

  private

  def enqueue_post_alerts
    Jobs.enqueue(:post_alert, post_id: @post.id)
  end

  def feature_topic_users
    Jobs.enqueue(:feature_topic_users, topic_id: @topic.id)
  end

  def trigger_post_post_process
    @post.trigger_post_process
  end

  def after_post_create
    TopicTrackingState.publish_unread(@post) if @post.post_number > 1
    TopicTrackingState.publish_latest(@topic)

    Jobs.enqueue_in(
        SiteSetting.email_time_window_mins.minutes,
        :notify_mailing_list_subscribers,
        post_id: @post.id
    )
  end

  def after_topic_create
    return unless @new_topic
    # Don't publish invisible topics
    return unless @topic.visible?

    @topic.posters = @topic.posters_summary
    @topic.posts_count = 1

    TopicTrackingState.publish_new(@topic)
  end

  def skip_after_create?
    @opts[:import_mode] ||
      @topic.private_message? ||
      @post.post_type == Post.types[:moderator_action] ||
      @post.post_type == Post.types[:small_action]
  end
end
