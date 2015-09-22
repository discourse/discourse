class PostMover
  attr_reader :original_topic, :destination_topic, :user, :post_ids

  def self.move_types
    @move_types ||= Enum.new(:new_topic, :existing_topic)
  end

  def initialize(original_topic, user, post_ids)
    @original_topic = original_topic
    @user = user
    @post_ids = post_ids
  end

  def to_topic(id)
    @move_type = PostMover.move_types[:existing_topic]

    Topic.transaction do
      move_posts_to Topic.find_by_id(id)
    end
  end

  def to_new_topic(title, category_id=nil)
    @move_type = PostMover.move_types[:new_topic]

    Topic.transaction do
      move_posts_to Topic.create!(
        user: user,
        title: title,
        category_id: category_id
      )
    end
  end

  private

  def move_posts_to(topic)
    Guardian.new(user).ensure_can_see! topic
    @destination_topic = topic

    move_each_post
    notify_users_that_posts_have_moved
    update_statistics
    update_user_actions
    set_last_post_user_id(destination_topic)

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
    end
  end

  def create_first_post(post)
    p = PostCreator.create(
      post.user,
      raw: post.raw,
      topic_id: destination_topic.id,
      acting_user: user
    )
    p.update_column(:reply_count, @reply_count[1] || 0)
  end

  def move(post)
    @first_post_number_moved ||= post.post_number

    Post.where(id: post.id, topic_id: original_topic.id).update_all(
      [
        ['post_number = :post_number',
         'reply_to_post_number = :reply_to_post_number',
         'topic_id    = :topic_id',
         'sort_order  = :post_number',
         'reply_count = :reply_count',
        ].join(', '),
        reply_count: @reply_count[post.post_number] || 0,
        post_number: @move_map[post.post_number],
        reply_to_post_number: @move_map[post.reply_to_post_number],
        topic_id: destination_topic.id
      ]
    )

    # Move any links from the post to the new topic
    post.topic_links.update_all(topic_id: destination_topic.id)
  end

  def update_statistics
    destination_topic.update_statistics
    original_topic.update_statistics
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

    original_topic.add_moderator_post(
      user,
      I18n.t("move_posts.#{move_type_str}_moderator_post",
             count: post_ids.count,
             topic_link: "[#{destination_topic.title}](#{destination_topic.relative_url})"),
      post_type: Post.types[:small_action],
      action_code: "split_topic",
      post_number: @first_post_number_moved
    )
  end

  def posts
    @posts ||= begin
      Post.where(id: post_ids).order(:created_at).tap do |posts|
        raise Discourse::InvalidParameters.new(:post_ids) if posts.empty?
      end
    end
  end

  def set_last_post_user_id(topic)
    user_id = topic.posts.last.user_id rescue nil
    return if user_id.nil?
    topic.update_attribute :last_post_user_id, user_id
  end
end
