# Responsible for creating posts and topics
#
require_dependency 'rate_limiter'

class PostCreator

  attr_reader :errors, :opts

  # Acceptable options:
  #
  #   raw                     - raw text of post
  #   image_sizes             - We can pass a list of the sizes of images in the post as a shortcut.
  #   invalidate_oneboxes     - Whether to force invalidation of oneboxes in this post
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
  #     meta_data             - Topic meta data hash
  def initialize(user, opts)
    @user = user
    @opts = opts
    raise Discourse::InvalidParameters.new(:raw) if @opts[:raw].blank?
  end

  def guardian
    @guardian ||= Guardian.new(@user)
  end

  def create
    topic = nil
    post = nil

    Post.transaction do
      if @opts[:topic_id].blank?
        topic_params = {title: @opts[:title], user_id: @user.id, last_post_user_id: @user.id}
        topic_params[:archetype] = @opts[:archetype] if @opts[:archetype].present?

        guardian.ensure_can_create!(Topic)

        category = Category.where(name: @opts[:category]).first
        topic_params[:category_id] = category.id if category.present?
        topic_params[:meta_data] = @opts[:meta_data] if @opts[:meta_data].present?

        topic = Topic.new(topic_params)

        if @opts[:archetype] == Archetype.private_message

          usernames = @opts[:target_usernames].split(',')
          User.where(username: usernames).each do |u|

            unless guardian.can_send_private_message?(u)
              topic.errors.add(:archetype, :cant_send_pm)
              @errors = topic.errors
              raise ActiveRecord::Rollback.new
            end

            topic.topic_allowed_users.build(user_id: u.id)
          end
          topic.topic_allowed_users.build(user_id: @user.id)
        end

        unless topic.save
          @errors = topic.errors
          raise ActiveRecord::Rollback.new
        end
      else
        topic = Topic.where(id: @opts[:topic_id]).first
        guardian.ensure_can_create!(Post, topic)
      end

      post = topic.posts.new(raw: @opts[:raw],
                             user: @user,
                             reply_to_post_number: @opts[:reply_to_post_number])

      post.post_type = @opts[:post_type] if @opts[:post_type].present?
      post.no_bump = @opts[:no_bump] if @opts[:no_bump].present?
      post.extract_quoted_post_numbers

      post.image_sizes = @opts[:image_sizes] if @opts[:image_sizes].present?
      post.invalidate_oneboxes = @opts[:invalidate_oneboxes] if @opts[:invalidate_oneboxes].present?
      unless post.save
        @errors = post.errors
        raise ActiveRecord::Rollback.new
      end

      # Extract links
      TopicLink.extract_from(post)

      # Enqueue a job to feature the users in the topic
      Jobs.enqueue(:feature_topic_users, topic_id: topic.id)

      # Trigger post processing
      post.trigger_post_process

      # Store unique post key
      if SiteSetting.unique_posts_mins > 0
        $redis.setex(post.unique_post_key, SiteSetting.unique_posts_mins.minutes.to_i, "1")
      end

      # send a mail to notify users in case of a private message
      if topic.private_message?
        topic.allowed_users.where(["users.email_private_messages = true and users.id != ?", @user.id]).each do |u|
          Jobs.enqueue_in(SiteSetting.email_time_window_mins.minutes, :user_email, type: :private_message, user_id: u.id, post_id: post.id)
        end
      end

      # Track the topic
      TopicUser.auto_track(@user.id, topic.id, TopicUser.notification_reasons[:created_post])

      # Update `last_posted_at` to match the post's created_at
      @user.update_column(:last_posted_at, post.created_at)

      # Publish the post in the message bus
      MessageBus.publish("/topic/#{post.topic_id}",
                    id: post.id,
                    created_at: post.created_at,
                    user: BasicUserSerializer.new(post.user).as_json(root: false),
                    post_number: post.post_number)

      # Advance the draft sequence
      post.advance_draft_sequence

      # Save the quote relationships
      post.save_reply_relationships
    end

    post
  end

  # Shortcut
  def self.create(user, opts)
    PostCreator.new(user, opts).create
  end

end
