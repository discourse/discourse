require_dependency 'guardian'
require_dependency 'topic_query'
require_dependency 'summarize'

class TopicView

  attr_accessor :topic, :min, :max, :draft, :draft_key, :draft_sequence, :posts

  def initialize(topic_id, user=nil, options={})
    @topic = find_topic(topic_id)
    raise Discourse::NotFound if @topic.blank?

    # Special case: If the topic is private and the user isn't logged in, ask them
    # to log in!
    if @topic.present? && @topic.private_message? && user.blank?
      raise Discourse::NotLoggedIn.new
    end

    Guardian.new(user).ensure_can_see!(@topic)
    @min, @max = 1, SiteSetting.posts_per_page
    @post_number, @page  = options[:post_number], options[:page]
    @posts = @topic.posts

    @posts = @posts.with_deleted if user.try(:admin?)
    @posts = @posts.best_of if options[:best_of].present?

    if options[:username_filters].present?
      usernames = options[:username_filters].map{|u| u.downcase}
      @posts = @posts.where('post_number = 1 or user_id in (select u.id from users u where username_lower in (?))', usernames)
    end

    @user = user
    @initial_load = true

    @all_posts = @posts

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
    last_post = @posts.last
    if last_post.present? && (@topic.highest_post_number > last_post.post_number)
      (@posts[0].post_number / SiteSetting.posts_per_page) + 1
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

  def summary
    return nil if posts.blank?
    Summarize.new(posts.first.cooked).summary
  end

  def image_url
    return nil if posts.blank?
    posts.first.user.small_avatar_url
  end

  def filter_posts(opts = {})
    if opts[:post_number].present?
      # Get posts near a post
      filter_posts_near(opts[:post_number].to_i)
    elsif opts[:posts_before].present?
      filter_posts_before(opts[:posts_before].to_i)
    elsif opts[:posts_after].present?
      filter_posts_after(opts[:posts_after].to_i)
    else
      # No filter? Consider it a paged view, default to page 0 which is the first segment
      filter_posts_paged(opts[:page].to_i)
    end
  end

  # Filter to all posts near a particular post number
  def filter_posts_near(post_number)
    @min, @max = post_range(post_number)
    filter_posts_in_range(@min, @max)
  end

  def post_numbers
    @post_numbers ||= @posts.order(:post_number).pluck(:post_number)
  end

  def filter_posts_paged(page)
    page ||= 0
    min = (SiteSetting.posts_per_page * page)
    max = min + SiteSetting.posts_per_page

    max_val = (post_numbers.length - 1)

    # If we're off the charts, return nil
    return nil if min > max_val

    # Pin max to the last post
    max = max_val if max > max_val

    filter_posts_in_range(post_numbers[min], post_numbers[max])
  end

  # Filter to all posts before a particular post number
  def filter_posts_before(post_number)
    @initial_load = false
    @max = post_number - 1

    @posts = @posts.reverse_order.where("post_number < ?", post_number)
    @posts = @posts.includes(:topic).joins(:user).limit(SiteSetting.posts_per_page)
    @min = @max - @posts.size
    @min = 1 if @min < 1
  end

  # Filter to all posts after a particular post number
  def filter_posts_after(post_number)
    @initial_load = false
    @min = post_number
    @posts = @posts.regular_order.where("post_number > ?", post_number)
    @posts = @posts.includes(:topic).joins(:user).limit(SiteSetting.posts_per_page)
    @max = @min + @posts.size
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

  def posts_count
    @posts_count ||= Post.where(topic_id: @topic.id).group(:user_id).order('count_all desc').limit(24).count
  end

  def participants
    @participants ||= begin
      participants = {}
      User.where(id: posts_count.map {|k,v| k}).each {|u| participants[u.id] = u}
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

  # Binary search for closest value
  def self.closest(array, target, min, max)
    return min if max <= min
    return max if (max - min) == 1

    middle_idx = ((min + max) / 2).floor
    middle_val = array[middle_idx]

    return middle_idx if target == middle_val
    return closest(array, target, min, middle_idx) if middle_val > target
    return closest(array, target, middle_idx, max)
  end

  # Find a range of posts, allowing for gaps by deleted posts.
  def post_range(post_number)
    closest_index = TopicView.closest(post_numbers, post_number, 0, post_numbers.size - 1)

    min_idx = closest_index - (SiteSetting.posts_per_page.to_f / 4).floor
    min_idx = 0 if min_idx < 0
    max_idx = min_idx + (SiteSetting.posts_per_page - 1)
    if max_idx > (post_numbers.length - 1)
      max_idx = post_numbers.length - 1
      min_idx = max_idx - SiteSetting.posts_per_page
      min_idx = 0 if min_idx < 0
    end

    [post_numbers[min_idx], post_numbers[max_idx]]
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
    @highest_post_number ||= @all_posts.maximum(:post_number)
  end

  def recent_posts
    @all_posts.by_newest.with_user.first(25)
  end

  protected

  def read_posts_set
    @read_posts_set ||= begin
      result = Set.new
      return result unless @user.present?
      return result unless topic_user.present?

      posts_max = @max > (topic_user.last_read_post_number || 1 ) ? (topic_user.last_read_post_number || 1) : @max

      PostTiming.select(:post_number)
                .where("topic_id = ? AND user_id = ? AND post_number BETWEEN ? AND ?",
                       @topic.id, @user.id, @min, posts_max)
                .each {|t| result << t.post_number}
      result
    end
  end

  private

  def filter_posts_in_range(min, max)
    @min, @max = min, max
    @posts = @posts.where("post_number between ? and ?", @min, @max).includes(:user).regular_order
  end

  def find_topic(topic_id)
    Topic.where(id: topic_id).includes(:category).first
  end
end
