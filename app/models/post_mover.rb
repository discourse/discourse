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

    destination_topic
  end

  def move_each_post
    with_max_post_number do |max_post_number|
      posts.each_with_index do |post, offset|
        post.is_first_post? ? copy(post) : move(post, offset + max_post_number)
      end
    end
  end

  def copy(post)
    PostCreator.create(
      post.user,
      raw: post.raw,
      topic_id: destination_topic.id,
      acting_user: user
    )
  end

  def move(post, post_number)
    @first_post_number_moved ||= post.post_number

    Post.where(id: post.id, topic_id: original_topic.id).update_all(
      [
        ['post_number = :post_number',
         'topic_id    = :topic_id',
         'sort_order  = :post_number'
        ].join(', '),
        post_number: post_number,
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
    original_topic.add_moderator_post(
      user,
      I18n.t("move_posts.#{PostMover.move_types[@move_type].to_s}_moderator_post",
             count: post_ids.count,
             topic_link: "[#{destination_topic.title}](#{destination_topic.url})"),
      post_number: @first_post_number_moved
    )
  end

  def with_max_post_number
    yield destination_topic.max_post_number + 1
  end

  def posts
    @posts ||= begin
      Post.where(id: post_ids).order(:created_at).tap do |posts|
        raise Discourse::InvalidParameters.new(:post_ids) if posts.empty?
      end
    end
  end
end
