# frozen_string_literal: true

class FilterBestPosts

  attr_accessor :filtered_posts, :posts

  def initialize(topic, filtered_posts, limit, options = {})
    @filtered_posts = filtered_posts
    @topic = topic
    @limit = limit
    options.each do |key, value|
      self.instance_variable_set("@#{key}".to_sym, value)
    end
    filter
  end

  def filter
    @posts =
      if @min_replies && @topic.posts_count < @min_replies + 1
        Post.none
      else
        filter_posts_liked_by_moderators
        setup_posts
        filter_posts_based_on_trust_level
        filter_posts_based_on_score
        sort_posts
      end
  end

  private

  def filter_posts_liked_by_moderators
    return unless @only_moderator_liked
    liked_by_moderators = PostAction.where(post_id: @filtered_posts.pluck(:id), post_action_type_id: PostActionType.types[:like])
    liked_by_moderators = liked_by_moderators.joins(:user).where('users.moderator').pluck(:post_id)
    @filtered_posts = @filtered_posts.where(id: liked_by_moderators)
  end

  def setup_posts
    @posts = @filtered_posts.order('percent_rank asc, sort_order asc').where("post_number > 1")
    @posts = @posts.includes(:reply_to_user).includes(:topic).joins(:user).limit(@limit)
  end

  def filter_posts_based_on_trust_level
    return unless @min_trust_level.try('>', 0)

    @posts =
      if @bypass_trust_level_score.try('>', 0)
        @posts.where('COALESCE(users.trust_level,0) >= ? OR posts.score >= ?',
          @min_trust_level,
          @bypass_trust_level_score
        )
      else
        @posts.where('COALESCE(users.trust_level,0) >= ?', @min_trust_level)
      end
  end

  def filter_posts_based_on_score
    return unless @min_score.try('>', 0)
    @posts = @posts.where('posts.score >= ?', @min_score)
  end

  def sort_posts
    @posts = Post.from(@posts, :posts).order(post_number: :asc)
  end

end
