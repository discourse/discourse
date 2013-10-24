# Responsible for creating posts and topics
#
require_dependency 'rate_limiter'
require_dependency 'topic_creator'

class PostCreator

  attr_reader :errors, :opts

  # Acceptable options:
  #
  #   raw                     - raw text of post
  #   image_sizes             - We can pass a list of the sizes of images in the post as a shortcut.
  #   invalidate_oneboxes     - Whether to force invalidation of oneboxes in this post
  #   acting_user             - The user performing the action might be different than the user
  #                             who is the post "author." For example when copying posts to a new
  #                             topic.
  #   created_at              - Post creation time (optional)
  #   auto_track              - Automatically track this topic if needed (default true)
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
  #     cooking_options       - Options for rendering the text
  #
  def initialize(user, opts)
    # TODO: we should reload user in case it is tainted, should take in a user_id as opposed to user
    # If we don't do this we introduce a rather risky dependency
    @user = user
    @opts = opts || {}
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
      consider_clearing_flags
      track_topic
      update_topic_stats
      update_user_counts
      publish
      ensure_in_allowed_users if guardian.is_staff?
      @post.advance_draft_sequence
      @post.save_reply_relationships
    end

    if @spam
      GroupMessage.create( Group[:moderators].name,
                           :spam_post_blocked,
                           { user: @user,
                             limit_once_per: 24.hours,
                             message_params: {domains: @post.linked_hosts.keys.join(', ')} } )
    elsif @post && !@post.errors.present?
      SpamRulesEnforcer.enforce!(@post)
    end

    track_latest_on_category

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

    cooking_options = post.cooking_options || {}
    cooking_options[:topic_id] = post.topic_id

    post.cooked ||= post.cook(post.raw, cooking_options)
    post.sort_order = post.post_number
    DiscourseEvent.trigger(:before_create_post, post)
    post.last_version_at ||= Time.now
  end


  protected

  def track_latest_on_category
    if @post && @post.errors.count == 0 && @topic && @topic.category_id
      Category.where(id: @topic.category_id).update_all(latest_post_id: @post.id)
      if @post.post_number == 1
        Category.where(id: @topic.category_id).update_all(latest_topic_id: @topic.id)
      end
    end
  end

  def ensure_in_allowed_users
    return unless @topic.private_message?

    unless @topic.topic_allowed_users.where(user_id: @user.id).exists?
      @topic.topic_allowed_users.create!(user_id: @user.id)
    end
  end

  def secure_group_ids(topic)
    @secure_group_ids ||= if topic.category && topic.category.read_restricted?
      topic.category.secure_group_ids
    end
  end

  def after_post_create
    if !@topic.private_message? && @post.post_number > 1 && @post.post_type != Post.types[:moderator_action]
      TopicTrackingState.publish_unread(@post)
    end
  end

  def after_topic_create
    # Don't publish invisible topics
    return unless @topic.visible?

    return if @topic.private_message? || @post.post_type == Post.types[:moderator_action]

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

  def update_topic_stats
    # Update attributes on the topic - featured users and last posted.
    attrs = {last_posted_at: @post.created_at, last_post_user_id: @post.user_id}
    attrs[:bumped_at] = @post.created_at unless @post.no_bump
    @topic.update_attributes(attrs)
  end

  def setup_post
    post = @topic.posts.new(raw: @opts[:raw],
                            user: @user,
                            reply_to_post_number: @opts[:reply_to_post_number])

    # Attributes we pass through to the post instance if present
    [:post_type, :no_bump, :cooking_options, :image_sizes, :acting_user, :invalidate_oneboxes].each do |a|
      post.send("#{a}=", @opts[a]) if @opts[a].present?
    end

    post.extract_quoted_post_numbers
    post.created_at = Time.zone.parse(@opts[:created_at].to_s) if @opts[:created_at].present?
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
    unless @post.save(validate: !@opts[:skip_validations])
      @errors = @post.errors
      raise ActiveRecord::Rollback.new
    end
  end

  def store_unique_post_key
    @post.store_unique_post_key
  end

  def consider_clearing_flags
    if @topic.private_message? && @post.post_number > 1 && @topic.user_id != @post.user_id
      clear_possible_flags(@topic)
    end
  end

  def update_user_counts
    # We don't count replies to your own topics
    if @user.id != @topic.user_id
      @user.user_stat.update_topic_reply_count
      @user.user_stat.save!
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
    unless @opts[:auto_track] == false
      TopicUser.auto_track(@user.id, @topic.id, TopicUser.notification_reasons[:created_post])
      # Update topic user data
      TopicUser.change(@post.user.id,
                       @post.topic.id,
                       posted: true,
                       last_read_post_number: @post.post_number,
                       seen_post_count: @post.post_number)
    end
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
