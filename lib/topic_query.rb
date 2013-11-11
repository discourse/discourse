#
# Helps us find topics. Returns a TopicList object containing the topics
# found.
#
require_dependency 'topic_list'
require_dependency 'suggested_topics_builder'

class TopicQuery
  # Could be rewritten to %i if Ruby 1.9 is no longer supported
  VALID_OPTIONS = %w(except_topic_id exclude_category limit page per_page topic_ids visible).map(&:to_sym)

  class << self
    # use the constants in conjuction with COALESCE to determine the order with regard to pinned
    # topics that have been cleared by the user. There
    # might be a cleaner way to do this.
    def lowest_date
      "2010-01-01"
    end

    def highest_date
      "3000-01-01"
    end

    # If you've clearned the pin, use bumped_at, otherwise put it at the top
    def order_with_pinned_sql
      "CASE
        WHEN (COALESCE(topics.pinned_at, '#{lowest_date}') > COALESCE(tu.cleared_pinned_at, '#{lowest_date}'))
          THEN '#{highest_date}'
        ELSE topics.bumped_at
       END DESC"
    end

    def order_hotness
      if @user
        # When logged in take into accounts what pins you've closed
        "CASE
          WHEN (COALESCE(topics.pinned_at, '#{lowest_date}') > COALESCE(tu.cleared_pinned_at, '#{lowest_date}'))
            THEN 100
          ELSE hot_topics.score + (COALESCE(categories.hotness, 5.0) / 11.0)
         END DESC"
      else
        # When anonymous, don't use topic_user
        "CASE
          WHEN topics.pinned_at IS NOT NULL THEN 100
          ELSE hot_topics.score + (COALESCE(categories.hotness, 5.0) / 11.0)
        END DESC"
      end
    end

    # If you've clearned the pin, use bumped_at, otherwise put it at the top
    def order_nocategory_with_pinned_sql
      "CASE
        WHEN topics.category_id IS NULL and (COALESCE(topics.pinned_at, '#{lowest_date}') > COALESCE(tu.cleared_pinned_at, '#{lowest_date}'))
          THEN '#{highest_date}'
        ELSE topics.bumped_at
       END DESC"
    end

    # For anonymous users
    def order_nocategory_basic_bumped
      "CASE WHEN topics.category_id IS NULL and (topics.pinned_at IS NOT NULL) THEN 0 ELSE 1 END, topics.bumped_at DESC"
    end

    def order_basic_bumped
      "CASE WHEN (topics.pinned_at IS NOT NULL) THEN 0 ELSE 1 END, topics.bumped_at DESC"
    end

    def top_viewed(max)
      Topic.listable_topics.visible.secured.order('views desc').take(10)
    end

    def recent(max)
      Topic.listable_topics.visible.secured.order('created_at desc').take(10)
    end
  end

  def initialize(user=nil, options={})
    options.assert_valid_keys(VALID_OPTIONS)

    @options = options
    @user = user
  end

  # Return a list of suggested topics for a topic
  def list_suggested_for(topic)
    builder = SuggestedTopicsBuilder.new(topic)

    # When logged in we start with different results
    if @user
      builder.add_results(unread_results(topic: topic, per_page: builder.results_left))
      builder.add_results(new_results(per_page: builder.results_left)) unless builder.full?
    end
    builder.add_results(random_suggested(topic, builder.results_left)) unless builder.full?

    create_list(:suggested, {}, builder.results)
  end

  # The latest view of topics
  def list_latest
    create_list(:latest)
  end

  # The favorited topics
  def list_favorited
    create_list(:favorited) {|topics| topics.where('tu.starred') }
  end

  def list_read
    create_list(:read, unordered: true) do |topics|
      topics.order('COALESCE(tu.last_visited_at, topics.bumped_at) DESC')
    end
  end

  def list_hot
    create_list(:hot, unordered: true) do |topics|
      topics.joins(:hot_topic).order(TopicQuery.order_hotness)
    end
  end

  def list_new
    create_list(:new, {}, new_results)
  end

  def list_unread
    create_list(:unread, {}, unread_results)
  end

  def list_posted
    create_list(:posted) {|l| l.where('tu.user_id IS NOT NULL') }
  end

  def list_topics_by(user)
    Rails.logger.info ">>> #{user.id}"
    create_list(:user_topics) do |topics|
      topics.where(user_id: user.id)
    end
  end


  def list_uncategorized
    create_list(:uncategorized, unordered: true) do |list|
      list = list.where(category_id: nil)

      if @user
        list.order(TopicQuery.order_with_pinned_sql)
      else
        list.order(TopicQuery.order_nocategory_basic_bumped)
      end
    end
  end

  def list_category(category)
    create_list(:category, unordered: true) do |list|
      list = list.where(category_id: category.id)
      if @user
        list.order(TopicQuery.order_with_pinned_sql)
      else
        list.order(TopicQuery.order_basic_bumped)
      end
    end
  end

  def list_new_in_category(category)
    create_list(:new_in_category) {|l| l.where(category_id: category.id).by_newest.first(25)}
  end

  def self.new_filter(list, treat_as_new_topic_start_date)
    list.where("topics.created_at >= :created_at", created_at: treat_as_new_topic_start_date)
        .where("tu.last_read_post_number IS NULL")
        .where("COALESCE(tu.notification_level, :tracking) >= :tracking", tracking: TopicUser.notification_levels[:tracking])
  end

  def self.unread_filter(list)
    list.where("tu.last_read_post_number < topics.highest_post_number")
        .where("COALESCE(tu.notification_level, :regular) >= :tracking", regular: TopicUser.notification_levels[:regular], tracking: TopicUser.notification_levels[:tracking])
  end

  def unread_count
    unread_results(limit: false).count
  end

  def new_count
    new_results(limit: false).count
  end

  protected

    def create_list(filter, options={}, topics = nil)
      topics ||= default_results(options)
      topics = yield(topics) if block_given?
      TopicList.new(filter, @user, topics)
    end

    # Create results based on a bunch of default options
    def default_results(options={})
      options.reverse_merge!(@options)
      options.reverse_merge!(per_page: SiteSetting.topics_per_page)

      # Start with a list of all topics
      result = Topic

      if @user
        result = result.joins("LEFT OUTER JOIN topic_users AS tu ON (topics.id = tu.topic_id AND tu.user_id = #{@user.id.to_i})")
      end

      unless options[:unordered]
        # If we're logged in, we have to pay attention to our pinned settings
        if @user
          result = result.order(TopicQuery.order_nocategory_with_pinned_sql)
        else
          result = result.order(TopicQuery.order_nocategory_basic_bumped)
        end
      end

      result = result.listable_topics.includes(category: :topic_only_relative_url)
      result = result.where('categories.name is null or categories.name <> ?', options[:exclude_category]) if options[:exclude_category]
      result = result.where('categories.name = ?', options[:only_category]) if options[:only_category]
      result = result.limit(options[:per_page]) unless options[:limit] == false
      result = result.visible if options[:visible] || @user.nil? || @user.regular?
      result = result.where('topics.id <> ?', options[:except_topic_id]) if options[:except_topic_id]
      result = result.offset(options[:page].to_i * options[:per_page]) if options[:page]

      if options[:topic_ids]
        result = result.where('topics.id in (?)', options[:topic_ids])
      end

      unless @user && @user.moderator?
        category_ids = @user.secure_category_ids if @user
        if category_ids.present?
          result = result.where('categories.read_restricted IS NULL OR categories.read_restricted = ? OR categories.id IN (?)', false, category_ids)
        else
          result = result.where('categories.read_restricted IS NULL OR categories.read_restricted = ?', false)
        end
      end

      result
    end

    def new_results(options={})
      TopicQuery.new_filter(default_results(options), @user.treat_as_new_topic_start_date)
    end

    def unread_results(options={})
      result = TopicQuery.unread_filter(default_results(options.reverse_merge(:unordered => true)))
                         .order('CASE WHEN topics.user_id = tu.user_id THEN 1 ELSE 2 END')

      # Prefer unread in the same category
      if options[:topic] && options[:topic].category_id
        result = result.order("CASE WHEN topics.category_id = #{options[:topic].category_id.to_i} THEN 0 ELSE 1 END")
      end

      result.order(TopicQuery.order_nocategory_with_pinned_sql)
    end

    def random_suggested(topic, count)
      result = default_results(unordered: true, per_page: count)

      # If we are in a category, prefer it for the random results
      if topic.category_id
        result = result.order("CASE WHEN topics.category_id = #{topic.category_id.to_i} THEN 0 ELSE 1 END")
      end

      result.order("RANDOM()")
    end

end
