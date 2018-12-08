class PostMover
  attr_reader :original_topic, :destination_topic, :user, :post_ids

  def self.move_types
    @move_types ||= Enum.new(:new_topic, :existing_topic)
  end

  def initialize(original_topic, user, post_ids, move_to_pm: false)
    @original_topic = original_topic
    @user = user
    @post_ids = post_ids
    @move_to_pm = move_to_pm
  end

  def to_topic(id, participants: nil)
    @move_type = PostMover.move_types[:existing_topic]

    topic = Topic.find_by_id(id)
    raise Discourse::InvalidParameters unless topic.archetype == @original_topic.archetype

    Topic.transaction do
      move_posts_to topic
    end
    add_allowed_users(participants) if participants.present? && @move_to_pm
    topic
  end

  def to_new_topic(title, category_id = nil, tags = nil)
    @move_type = PostMover.move_types[:new_topic]

    post = Post.find_by(id: post_ids.first)
    raise Discourse::InvalidParameters unless post
    archetype = @move_to_pm ? Archetype.private_message : Archetype.default

    Topic.transaction do
      new_topic = Topic.create!(
        user: post.user,
        title: title,
        category_id: category_id,
        created_at: post.created_at,
        archetype: archetype
      )
      DiscourseTagging.tag_topic_by_names(new_topic, Guardian.new(user), tags)
      move_posts_to new_topic
      watch_new_topic
      new_topic
    end
  end

  private

  def move_posts_to(topic)
    Guardian.new(user).ensure_can_see! topic
    @destination_topic = topic

    moving_all_posts = (@original_topic.posts.pluck(:id).sort == @post_ids.sort)

    move_each_post
    notify_users_that_posts_have_moved
    update_statistics
    update_user_actions
    update_last_post_stats

    if moving_all_posts
      @original_topic.update_status('closed', true, @user)
    end

    destination_topic.reload
    destination_topic
  end

  def move_each_post
    max_post_number = destination_topic.max_post_number + 1

    @move_map = {}
    @reply_count = {}
    posts.each_with_index do |post, offset|
      unless post.is_first_post?
        @move_map[post.post_number] = offset + max_post_number
      else
        @move_map[post.post_number] = 1
      end
      if post.reply_to_post_number.present?
        @reply_count[post.reply_to_post_number] = (@reply_count[post.reply_to_post_number] || 0) + 1
      end
    end

    posts.each do |post|
      post.is_first_post? ? create_first_post(post) : move(post)
      if @move_to_pm
        destination_topic.topic_allowed_users.build(user_id: post.user_id) unless destination_topic.topic_allowed_users.where(user_id: post.user_id).exists?
      end
    end
    destination_topic.save! if @move_to_pm

    PostReply.where("reply_id IN (:post_ids) OR post_id IN (:post_ids)", post_ids: post_ids).each do |post_reply|
      if post_reply.post && post_reply.reply && post_reply.reply.topic_id != post_reply.post.topic_id
        PostReply
          .where(reply_id: post_reply.reply.id, post_id: post_reply.post.id)
          .delete_all
      end
    end
  end

  def create_first_post(post)
    new_post = PostCreator.create(
      post.user,
      raw: post.raw,
      topic_id: destination_topic.id,
      acting_user: user,
      cook_method: post.cook_method,
      via_email: post.via_email,
      raw_email: post.raw_email,
      skip_validations: true,
      created_at: post.created_at,
      guardian: Guardian.new(user)
    )

    move_incoming_emails(post, new_post)
    move_email_logs(post, new_post)

    PostAction.copy(post, new_post)
    new_post.update_column(:reply_count, @reply_count[1] || 0)
    new_post.custom_fields = post.custom_fields
    new_post.save_custom_fields

    DiscourseEvent.trigger(:post_moved, new_post, original_topic.id)

    new_post
  end

  def move(post)
    @first_post_number_moved ||= post.post_number

    update = {
      reply_count: @reply_count[post.post_number] || 0,
      post_number: @move_map[post.post_number],
      reply_to_post_number: @move_map[post.reply_to_post_number],
      topic_id: destination_topic.id,
      sort_order: @move_map[post.post_number]
    }

    unless @move_map[post.reply_to_post_number]
      update[:reply_to_user_id] = nil
    end

    post.attributes = update
    post.save(validate: false)

    move_incoming_emails(post, post)
    move_email_logs(post, post)

    DiscourseEvent.trigger(:post_moved, post, original_topic.id)

    # Move any links from the post to the new topic
    post.topic_links.update_all(topic_id: destination_topic.id)
  end

  def move_incoming_emails(old_post, new_post)
    return if old_post.incoming_email.nil?

    email = old_post.incoming_email
    email.update_columns(topic_id: new_post.topic_id, post_id: new_post.id)
    new_post.incoming_email = email
  end

  def move_email_logs(old_post, new_post)
    EmailLog
      .where(post_id: old_post.id)
      .update_all(post_id: new_post.id)
  end

  def update_statistics
    destination_topic.update_statistics
    original_topic.update_statistics
    TopicUser.update_post_action_cache(topic_id: original_topic.id, post_action_type: :bookmark)
    TopicUser.update_post_action_cache(topic_id: destination_topic.id, post_action_type: :bookmark)
  end

  def update_user_actions
    UserAction.synchronize_target_topic_ids(posts.map(&:id))
  end

  def notify_users_that_posts_have_moved
    enqueue_notification_job
    create_moderator_post_in_original_topic
  end

  def enqueue_notification_job
    Jobs.enqueue(
      :notify_moved_posts,
      post_ids: post_ids,
      moved_by_id: user.id
    )
  end

  def create_moderator_post_in_original_topic
    move_type_str = PostMover.move_types[@move_type].to_s

    message = I18n.with_locale(SiteSetting.default_locale) do
      I18n.t(
        "move_posts.#{move_type_str}_moderator_post",
        count: posts.length,
        entity: @move_to_pm ? "message" : "topic",
        topic_link: posts.first.is_first_post? ?
          "[#{destination_topic.title}](#{destination_topic.relative_url})" :
          "[#{destination_topic.title}](#{posts.first.url})"
      )
    end

    original_topic.add_moderator_post(
      user, message,
      post_type: Post.types[:small_action],
      action_code: "split_topic",
      post_number: @first_post_number_moved
    )
  end

  def posts
    @posts ||= begin
      Post.where(topic: @original_topic, id: post_ids)
        .where.not(post_type: Post.types[:small_action])
        .order(:created_at).tap do |posts|

        raise Discourse::InvalidParameters.new(:post_ids) if posts.empty?
      end
    end
  end

  def update_last_post_stats
    post = destination_topic.ordered_posts.where.not(post_type: Post.types[:whisper]).last
    if post && post_ids.include?(post.id)
      attrs = {}
      attrs[:last_posted_at] = post.created_at
      attrs[:last_post_user_id] = post.user_id
      attrs[:bumped_at] = post.created_at unless post.no_bump
      attrs[:updated_at] = Time.now
      destination_topic.update_columns(attrs)
    end
  end

  def watch_new_topic
    TopicUser.change(
      destination_topic.user,
      destination_topic.id,
      notification_level: TopicUser.notification_levels[:watching],
      notifications_reason_id: TopicUser.notification_reasons[:created_topic]
    )
  end

  def add_allowed_users(usernames)
    return unless usernames.present?

    names = usernames.split(',').flatten
    User.where(username: names).find_each do |user|
      destination_topic.topic_allowed_users.build(user_id: user.id) unless destination_topic.topic_allowed_users.where(user_id: user.id).exists?
    end
    destination_topic.save!
  end
end
