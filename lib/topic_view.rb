require_dependency 'guardian'
require_dependency 'topic_query'
require_dependency 'summarize'

class TopicView

  attr_reader :topic, :posts, :index_offset, :index_reverse
  attr_accessor :draft, :draft_key, :draft_sequence

  def initialize(topic_id, user=nil, options={})
    @topic = find_topic(topic_id)
    raise Discourse::NotFound if @topic.blank?

    # Special case: If the topic is private and the user isn't logged in, ask them
    # to log in!
    if @topic.present? && @topic.private_message? && user.blank?
      raise Discourse::NotLoggedIn.new
    end

    Guardian.new(user).ensure_can_see!(@topic)
    @post_number, @page  = options[:post_number], options[:page]

    @limit = options[:limit] || SiteSetting.posts_per_page;

    @filtered_posts = @topic.posts
    @filtered_posts = @filtered_posts.with_deleted if user.try(:staff?)
    @filtered_posts = @filtered_posts.best_of if options[:best_of].present?

    if options[:username_filters].present?
      usernames = options[:username_filters].map{|u| u.downcase}
      @filtered_posts = @filtered_posts.where('post_number = 1 or user_id in (select u.id from users u where username_lower in (?))', usernames)
    end

    @user = user
    @initial_load = true
    @index_reverse = false

    filter_posts(options)

    @draft_key = @topic.draft_key
    @draft_sequence = DraftSequence.current(user, @draft_key)
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

  def next_page
    last_post = @filtered_posts.last
    if last_post.present? && (@topic.highest_post_number > last_post.post_number)
      (@filtered_posts[0].post_number / SiteSetting.posts_per_page) + 1
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

  def filtered_posts_count
    @filtered_posts_count ||= @filtered_posts.count
  end

  def summary
    return nil if posts.blank?
    Summarize.new(posts.first.cooked).summary
  end

  def image_url
    return nil if posts.blank?
    posts.first.user.small_avatar_url
  end

  def filter_posts(opts = {})
    return filter_posts_near(opts[:post_number].to_i) if opts[:post_number].present?
    return filter_posts_before(opts[:posts_before].to_i) if opts[:posts_before].present?
    return filter_posts_after(opts[:posts_after].to_i) if opts[:posts_after].present?
    return filter_best(opts[:best]) if opts[:best].present?
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

    # Find the closest number we have
    closest_post_id = @filtered_posts.order("@(post_number - #{post_number})").first.try(:id)
    return nil if closest_post_id.blank?

    closest_index = filtered_post_ids.index(closest_post_id)
    return nil if closest_index.blank?

    # Make sure to get at least one post before, even with rounding
    posts_before = (SiteSetting.posts_per_page.to_f / 4).floor
    posts_before = 1 if posts_before == 0

    min_idx = closest_index - posts_before
    min_idx = 0 if min_idx < 0
    max_idx = min_idx + (SiteSetting.posts_per_page - 1)

    # Get a full page even if at the end
    upper_limit = (filtered_post_ids.length - 1)
    if max_idx >= upper_limit
      max_idx = upper_limit
      min_idx = (upper_limit - SiteSetting.posts_per_page) + 1
    end

    filter_posts_in_range(min_idx, max_idx)
  end

  def filtered_post_ids
    @filtered_post_ids ||= @filtered_posts.order(:sort_order).pluck(:id)
  end

  def filter_posts_paged(page)
    page = [page, 1].max
    min = SiteSetting.posts_per_page * (page - 1)
    max = min + SiteSetting.posts_per_page
    filter_posts_in_range(min, max)
  end

  # Filter to all posts before a particular post number
  def filter_posts_before(post_number)
    @initial_load = false

    sort_order = sort_order_for_post_number(post_number)
    return nil unless sort_order

    # Find posts before the `sort_order`
    @posts = @filtered_posts.order('sort_order desc').where("sort_order < ?", sort_order)
    @index_offset = @posts.count
    @index_reverse = true

    @posts = @posts.includes(:reply_to_user).includes(:topic).joins(:user).limit(@limit)
  end

  # Filter to all posts after a particular post number
  def filter_posts_after(post_number)
    @initial_load = false

    sort_order = sort_order_for_post_number(post_number)
    return nil unless sort_order

    @index_offset = @filtered_posts.where("sort_order <= ?", sort_order).count
    @posts = @filtered_posts.order('sort_order').where("sort_order > ?", sort_order)
    @posts = @posts.includes(:reply_to_user).includes(:topic).joins(:user).limit(@limit)
  end

  def filter_best(max)
    @index_offset = 0
    @posts = @filtered_posts.order('percent_rank asc, sort_order asc').where("post_number > 1")
    @posts = @posts.includes(:reply_to_user).includes(:topic).joins(:user).limit(max)
    @posts = @posts.to_a
    @posts.sort!{|a,b| a.post_number <=> b.post_number}
    @posts
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

  def voted_in_topic?
    return false

    # all post_actions is not the way to do this, cut down on the query, roll it up into topic if we need it

    @voted_in_topic ||= begin
      return false unless all_post_actions.present?
      all_post_actions.values.flatten.map {|ac| ac.keys}.flatten.include?(PostActionType.types[:vote])
    end
  end

  def post_action_visibility
    @post_action_visibility ||= begin
      result = []
      PostActionType.types.each do |k, v|
        result << v if Guardian.new(@user).can_see_post_actors?(@topic, v)
      end
      result
    end
  end

  def links
    @links ||= @topic.links_grouped
  end

  def link_counts
    @link_counts ||= TopicLinkClick.counts_for(@topic, posts)
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

  protected

  def read_posts_set
    @read_posts_set ||= begin
      result = Set.new
      return result unless @user.present?
      return result unless topic_user.present?

      post_numbers = PostTiming.select(:post_number)
                .where(topic_id: @topic.id, user_id: @user.id)
                .where(post_number: @posts.pluck(:post_number))
                .pluck(:post_number)

      post_numbers.each {|pn| result << pn}
      result
    end
  end

  private

  def filter_posts_in_range(min, max)
    max_index = (filtered_post_ids.length - 1)

    # If we're off the charts, return nil
    return nil if min > max_index

    # Pin max to the last post
    max = max_index if max > max_index
    min = 0 if min < 0

    @index_offset = min

    # TODO: Sort might be off
    @posts = Post.where(id: filtered_post_ids[min..max])
                 .includes(:user)
                 .includes(:reply_to_user)
                 .order('sort_order')
    @posts = @posts.with_deleted if @user.try(:staff?)

    @posts
  end

  def find_topic(topic_id)
    Topic.where(id: topic_id).includes(:category).first
  end
end
