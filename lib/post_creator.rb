# Responsible for creating posts and topics
#
require_dependency 'rate_limiter'
require_dependency 'topic_creator'

class PostCreator

  attr_reader :errors, :opts

  def self.create(user,opts)
    self.new(user,opts).create
  end

  # Acceptable options:
  #
  #   raw                     - raw text of post
  #   image_sizes             - We can pass a list of the sizes of images in the post as a shortcut.
  #   invalidate_oneboxes     - Whether to force invalidation of oneboxes in this post
  #   acting_user             - The user performing the action might be different than the user
  #                             who is the post "author." For example when copying posts to a new
  #                             topic.
  #   created_at              - Post creation time (optional)
  #
  #   When replying to a topic:
  #     topic_id              - topic we're replying to
  #     reply_to_post_number  - post number we're replying to
  #
  #   When creating a topic:
  #     title                 - New topic title
  #     archetype             - Topic archetype
  #     category              - Category to assign to topic
  #     target_usernames      - comma delimited list of usernames for membership (private message)
  #     target_group_names    - comma delimited list of groups for membership (private message)
  #     meta_data             - Topic meta data hash
  def initialize(user, opts)
    # TODO: we should reload user in case it is tainted, should take in a user_id as opposed to user
    # If we don't do this we introduce a rather risky dependency
    @user = user
    @opts = opts
    @spam = false
  end

  # True if the post was considered spam
  def spam?
    @spam
  end

  def guardian
    @guardian ||= Guardian.new(@user)
  end

  def create
    @topic = nil
    @post = nil
    @new_topic = false

    Post.transaction do
      setup_topic
      setup_post
      rollback_if_host_spam_detected
      save_post
      extract_links
      store_unique_post_key
      send_notifications_for_private_message
      track_topic
      update_user_counts
      publish
      @post.advance_draft_sequence
      @post.save_reply_relationships
    end

    if @spam
      GroupMessage.create( Group[:moderators].name, :spam_post_blocked, {user: @user, limit_once_per: 24.hours} )
    end

    enqueue_jobs
    @post
  end

  def self.create(user, opts)
    PostCreator.new(user, opts).create
  end

  def self.before_create_tasks(post)
    if post.reply_to_post_number.present?
      post.reply_to_user_id ||= Post.select(:user_id).where(topic_id: post.topic_id, post_number: post.reply_to_post_number).first.try(:user_id)
    end

    post.post_number ||= Topic.next_post_number(post.topic_id, post.reply_to_post_number.present?)
    post.cooked ||= post.cook(post.raw, topic_id: post.topic_id)
    post.sort_order = post.post_number
    DiscourseEvent.trigger(:before_create_post, post)
    post.last_version_at ||= Time.now
  end

  def self.after_create_tasks(post)
    Rails.logger.info (">" * 30) + "#{post.no_bump} #{post.created_at}"
    # Update attributes on the topic - featured users and last posted.
    attrs = {last_posted_at: post.created_at, last_post_user_id: post.user_id}
    attrs[:bumped_at] = post.created_at unless post.no_bump
    post.topic.update_attributes(attrs)

    # Update topic user data
    TopicUser.change(post.user,
                     post.topic.id,
                     posted: true,
                     last_read_post_number: post.post_number,
                     seen_post_count: post.post_number)
  end

  protected

  def secure_group_ids(topic)
    @secure_group_ids ||= if topic.category && topic.category.secure?
      topic.category.secure_group_ids
    end
  end

  def after_post_create
    if @post.post_number > 1
      TopicTrackingState.publish_unread(@post)
    end
  end

  def after_topic_create

    # Don't publish invisible topics
    return unless @topic.visible?

    return if @topic.private_message?

    @topic.posters = @topic.posters_summary
    @topic.posts_count = 1

    TopicTrackingState.publish_new(@topic)
  end


  def clear_possible_flags(topic)
    # at this point we know the topic is a PM and has been replied to ... check if we need to clear any flags
    #
    first_post = Post.select(:id).where(topic_id: topic.id).where('post_number = 1').first
    post_action = nil

    if first_post
      post_action = PostAction.where(
        related_post_id: first_post.id,
        deleted_at: nil,
        post_action_type_id: PostActionType.types[:notify_moderators]
      ).first
    end

    if post_action
      post_action.remove_act!(@user)
    end
  end

  private

  def setup_topic
    if @opts[:topic_id].blank?
      topic_creator = TopicCreator.new(@user, guardian, @opts)

      begin
        topic = topic_creator.create
        @errors = topic_creator.errors
      rescue ActiveRecord::Rollback => ex
        # In the event of a rollback, grab the errors from the topic
        @errors = topic_creator.errors
        raise ex
      end

      @new_topic = true
    else
      topic = Topic.where(id: @opts[:topic_id]).first
      guardian.ensure_can_create!(Post, topic)
    end
    @topic = topic
  end

  def setup_post
    post = @topic.posts.new(raw: @opts[:raw],
                           user: @user,
                           reply_to_post_number: @opts[:reply_to_post_number])

    post.post_type = @opts[:post_type] if @opts[:post_type].present?
    post.no_bump = @opts[:no_bump] if @opts[:no_bump].present?
    post.extract_quoted_post_numbers
    post.acting_user = @opts[:acting_user] if @opts[:acting_user].present?
    post.created_at = Time.zone.parse(@opts[:created_at].to_s) if @opts[:created_at].present?

    post.image_sizes = @opts[:image_sizes] if @opts[:image_sizes].present?
    post.invalidate_oneboxes = @opts[:invalidate_oneboxes] if @opts[:invalidate_oneboxes].present?
    @post = post
  end

  def rollback_if_host_spam_detected
    if @post.has_host_spam?
      @post.errors.add(:base, I18n.t(:spamming_host))
      @errors = @post.errors
      @spam = true
      raise ActiveRecord::Rollback.new
    end
  end

  def save_post
    unless @post.save
      @errors = @post.errors
      raise ActiveRecord::Rollback.new
    end
  end

  def store_unique_post_key
    if SiteSetting.unique_posts_mins > 0
      $redis.setex(@post.unique_post_key, SiteSetting.unique_posts_mins.minutes.to_i, "1")
    end
  end

  def send_notifications_for_private_message
    # send a mail to notify users in case of a private message
    if @topic.private_message?
      @topic.allowed_users.where(["users.email_private_messages = true and users.id != ?", @user.id]).each do |u|
        Jobs.enqueue_in(SiteSetting.email_time_window_mins.minutes,
                          :user_email,
                          type: :private_message,
                          user_id: u.id,
                          post_id: @post.id
                       )
      end

      clear_possible_flags(@topic) if @post.post_number > 1 && @topic.user_id != @post.user_id
    end
  end

  def update_user_counts
    # We don't count replies to your own topics
    if @user.id != @topic.user_id
      @user.update_topic_reply_count
    end

    @user.last_posted_at = @post.created_at
    @user.save!
  end

  def publish
    if @post.post_number > 1
      MessageBus.publish("/topic/#{@post.topic_id}",{
                      id: @post.id,
                      created_at: @post.created_at,
                      user: BasicUserSerializer.new(@post.user).as_json(root: false),
                      post_number: @post.post_number
                    },
                    group_ids: secure_group_ids(@topic)
      )
    end
  end

  def extract_links
    TopicLink.extract_from(@post)
  end

  def track_topic
    TopicUser.auto_track(@user.id, @topic.id, TopicUser.notification_reasons[:created_post])
  end

  def enqueue_jobs
    if @post && !@post.errors.present?
      # We need to enqueue jobs after the transaction. Otherwise they might begin before the data has
      # been comitted.
      topic_id = @opts[:topic_id] || @topic.try(:id)
      Jobs.enqueue(:feature_topic_users, topic_id: @topic.id) if topic_id.present?
      @post.trigger_post_process
      after_post_create
      after_topic_create if @new_topic
    end
  end
end
