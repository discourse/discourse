# frozen_string_literal: true

class PostJobsEnqueuer
  def initialize(post, topic, new_topic, opts = {})
    @post = post
    @topic = topic
    @new_topic = new_topic
    @opts = opts
  end

  def enqueue_jobs
    # We need to enqueue jobs after the transaction.
    # Otherwise they might begin before the data has been committed.
    enqueue_post_alerts unless @opts[:import_mode]
    feature_topic_users unless @opts[:import_mode]
    trigger_post_post_process

    unless skip_after_create?
      after_post_create
      after_topic_create
      make_visible
    end
  end

  private

  def enqueue_post_alerts
    Jobs.enqueue(
      :post_alert,
      post_id: @post.id,
      new_record: true,
      options: @opts[:post_alert_options],
    )
  end

  def feature_topic_users
    Jobs.enqueue(:feature_topic_users, topic_id: @topic.id)
  end

  def trigger_post_post_process
    @post.trigger_post_process(new_post: true)
  end

  def make_visible
    return if @topic.private_message?
    return unless SiteSetting.embed_unlisted? || SiteSetting.import_embed_unlisted?
    return if @post.post_number == 1
    return if @topic.visible?
    return if @post.post_type != Post.types[:regular]

    Jobs.enqueue(:make_embedded_topic_visible, topic_id: @topic.id) if @topic.topic_embed.present?
  end

  def after_post_create
    Jobs.enqueue(:post_update_topic_tracking_state, post_id: @post.id)

    if !@topic.private_message?
      Jobs.enqueue_in(
        SiteSetting.email_time_window_mins.minutes,
        :notify_mailing_list_subscribers,
        post_id: @post.id,
      )
    end
  end

  def after_topic_create
    return unless @new_topic
    # Don't publish invisible topics
    return unless @topic.visible?

    @topic.posters = @topic.posters_summary
    @topic.posts_count = 1

    klass =
      if @topic.private_message?
        PrivateMessageTopicTrackingState
      else
        TopicTrackingState
      end

    klass.publish_new(@topic)
  end

  def skip_after_create?
    @opts[:import_mode] || @post.post_type == Post.types[:moderator_action] ||
      @post.post_type == Post.types[:small_action]
  end
end
