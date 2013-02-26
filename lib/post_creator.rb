# Responsible for creating posts and topics
#
require_dependency 'rate_limiter'

class PostCreator

  # Errors when creating the post
  attr_reader :errors

  # Acceptable options:
  #
  #   raw                     - raw text of post
  #   image_sizes             - We can pass a list of the sizes of images in the post as a shortcut.
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
          User.where(:username => usernames).each do |u|

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
      post.image_sizes = @opts[:image_sizes] if @opts[:image_sizes].present?
      unless post.save
        @errors = post.errors
        raise ActiveRecord::Rollback.new
      end

      # Extract links
      TopicLink.extract_from(post)
    end

    post
  end

  # Shortcut
  def self.create(user, opts)
    PostCreator.new(user, opts).create
  end

end
