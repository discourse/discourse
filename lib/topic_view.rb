require_dependency 'guardian'
require_dependency 'topic_query'
require_dependency 'filter_best_posts'
require_dependency 'summarize'

class TopicView

  attr_reader :topic, :posts, :guardian, :filtered_posts
  attr_accessor :draft, :draft_key, :draft_sequence

  def initialize(topic_id, user=nil, options={})
    @user = user
    @topic = find_topic(topic_id)
    @guardian = Guardian.new(@user)
    check_and_raise_exceptions

    options.each do |key, value|
      self.instance_variable_set("@#{key}".to_sym, value)
    end

    @page = @page.to_i
    @page = 1 if @page.zero?
    @limit ||= SiteSetting.posts_per_page

    setup_filtered_posts

    @initial_load = true
    @index_reverse = false

    filter_posts(options)

    @draft_key = @topic.draft_key
    @draft_sequence = DraftSequence.current(@user, @draft_key)
  end

  def canonical_path
    path = @topic.relative_url
    path << if @post_number
      page = ((@post_number.to_i - 1) / SiteSetting.posts_per_page) + 1
      (page > 1) ? "?page=#{page}" : ""
    else
      (@page && @page.to_i > 1) ? "?page=#{@page}" : ""
    end
    path
  end

  def last_post
    return nil if @posts.blank?
    @last_post ||= @posts.last
  end

  def next_page
    @next_page ||= begin
      if last_post && (@topic.highest_post_number > last_post.post_number)
        @page + 1
      end
    end
  end

  def next_page_path
    "#{@topic.relative_url}?page=#{next_page}"
  end

  def absolute_url
    "#{Discourse.base_url}#{@topic.relative_url}"
  end

  def relative_url
    @topic.relative_url
  end

  def title
    @topic.title
  end

  def desired_post
    return @desired_post if @desired_post.present?
    return nil if posts.blank?

    @desired_post = posts.detect {|p| p.post_number == @post_number.to_i}
    @desired_post ||= posts.first
    @desired_post
  end

  def summary
    return nil if desired_post.blank?
    # TODO, this is actually quite slow, should be cached in the post table
    Summarize.new(desired_post.cooked).summary
  end

  def image_url
    return nil if desired_post.blank?
    desired_post.user.try(:small_avatar_url)
  end

  def filter_posts(opts = {})
    return filter_posts_near(opts[:post_number].to_i) if opts[:post_number].present?
    return filter_posts_by_ids(opts[:post_ids]) if opts[:post_ids].present?
    return filter_best(opts[:best], opts) if opts[:best].present?

    filter_posts_paged(opts[:page].to_i)
  end


  # Find the sort order for a post in the topic
  def sort_order_for_post_number(post_number)
    Post.where(topic_id: @topic.id, post_number: post_number)
        .with_deleted
        .select(:sort_order)
        .first
        .try(:sort_order)
  end

  # Filter to all posts near a particular post number
  def filter_posts_near(post_number)

    min_idx, max_idx = get_minmax_ids(post_number)

    filter_posts_in_range(min_idx, max_idx)
  end


  def filter_posts_paged(page)
    page = [page, 1].max
    min = SiteSetting.posts_per_page * (page - 1)
    max = (min + SiteSetting.posts_per_page) - 1

    filter_posts_in_range(min, max)
  end

  def filter_best(max, opts={})
    filter = FilterBestPosts.new(@topic, @filtered_posts, max, opts)
    @posts = filter.posts
    @filtered_posts = filter.filtered_posts
  end

  def read?(post_number)
    read_posts_set.include?(post_number)
  end

  def topic_user
    @topic_user ||= begin
      return nil if @user.blank?
      @topic.topic_users.where(user_id: @user.id).first
    end
  end

  def post_counts_by_user
    @post_counts_by_user ||= Post.where(topic_id: @topic.id).group(:user_id).order('count_all desc').limit(24).count
  end

  def participants
    @participants ||= begin
      participants = {}
      User.where(id: post_counts_by_user.map {|k,v| k}).each {|u| participants[u.id] = u}
      participants
    end
  end

  def all_post_actions
    @all_post_actions ||= PostAction.counts_for(posts, @user)
  end

  def links
    @links ||= TopicLink.topic_summary(guardian, @topic.id)
  end

  def link_counts
    @link_counts ||= TopicLink.counts_for(guardian,@topic, posts)
  end

  # Are we the initial page load? If so, we can return extra information like
  # user post counts, etc.
  def initial_load?
    @initial_load
  end

  def suggested_topics
    return nil if topic.private_message?
    @suggested_topics ||= TopicQuery.new(@user).list_suggested_for(topic)
  end

  # This is pending a larger refactor, that allows custom orders
  #  for now we need to look for the highest_post_number in the stream
  #  the cache on topics is not correct if there are deleted posts at
  #  the end of the stream (for mods), nor is it correct for filtered
  #  streams
  def highest_post_number
    @highest_post_number ||= @filtered_posts.maximum(:post_number)
  end

  def recent_posts
    @filtered_posts.by_newest.with_user.first(25)
  end


  def current_post_ids
    @current_post_ids ||= if @posts.is_a?(Array)
      @posts.map {|p| p.id }
    else
      @posts.pluck(:post_number)
    end
  end

  def filtered_post_ids
    @filtered_post_ids ||= filter_post_ids_by(:sort_order)
  end

  protected

  def read_posts_set
    @read_posts_set ||= begin
      result = Set.new
      return result unless @user.present?
      return result unless topic_user.present?

      post_numbers = PostTiming
                .where(topic_id: @topic.id, user_id: @user.id)
                .where(post_number: current_post_ids)
                .pluck(:post_number)

      post_numbers.each {|pn| result << pn}
      result
    end
  end

  private

  def filter_posts_by_ids(post_ids)
    # TODO: Sort might be off
    @posts = Post.where(id: post_ids)
                 .includes(:user)
                 .includes(:reply_to_user)
                 .order('sort_order')
    @posts = @posts.with_deleted if @user.try(:staff?)
    @posts
  end

  def filter_posts_in_range(min, max)
    post_count = (filtered_post_ids.length - 1)

    max = [max, post_count].min

    return @posts = [] if min > max

    min = [[min, max].min, 0].max

    @posts = filter_posts_by_ids(filtered_post_ids[min..max])
    @posts
  end

  def find_topic(topic_id)
    finder = Topic.where(id: topic_id).includes(:category)
    finder = finder.with_deleted if @user.try(:staff?)
    finder.first
  end

  def setup_filtered_posts
    @filtered_posts = @topic.posts
    @filtered_posts = @filtered_posts.with_deleted if @user.try(:staff?)
    @filtered_posts = @filtered_posts.best_of if @filter == 'best_of'
    @filtered_posts = @filtered_posts.where('posts.post_type <> ?', Post.types[:moderator_action]) if @best.present?
    return unless @username_filters.present?
    usernames = @username_filters.map{|u| u.downcase}
    @filtered_posts = @filtered_posts.where('post_number = 1 or user_id in (select u.id from users u where username_lower in (?))', usernames)
  end

  def check_and_raise_exceptions
    raise Discourse::NotFound if @topic.blank?
    # Special case: If the topic is private and the user isn't logged in, ask them
    # to log in!
    if @topic.present? && @topic.private_message? && @user.blank?
      raise Discourse::NotLoggedIn.new
    end
    guardian.ensure_can_see!(@topic)
  end


  def filter_post_ids_by(sort_order)
    @filtered_posts.order(sort_order).pluck(:id)
  end

  def get_minmax_ids(post_number)
    # Find the closest number we have
    closest_index = closest_post_to(post_number)
    return nil if closest_index.nil?

    # Make sure to get at least one post before, even with rounding
    posts_before = (SiteSetting.posts_per_page.to_f / 4).floor
    posts_before = 1 if posts_before.zero?

    min_idx = closest_index - posts_before
    min_idx = 0 if min_idx < 0
    max_idx = min_idx + (SiteSetting.posts_per_page - 1)

    # Get a full page even if at the end
    ensure_full_page(min_idx, max_idx)
  end

  def ensure_full_page(min, max)
    upper_limit = (filtered_post_ids.length - 1)
    if max >= upper_limit
      return (upper_limit - SiteSetting.posts_per_page) + 1, upper_limit
    else
      return min, max
    end
  end

  def closest_post_to(post_number)
    closest_posts = filter_post_ids_by("@(post_number - #{post_number})")
    return nil if closest_posts.empty?

    filtered_post_ids.index(closest_posts.first)
  end

end
