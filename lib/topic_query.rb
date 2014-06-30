#
# Helps us find topics. Returns a TopicList object containing the topics
# found.
#
require_dependency 'topic_list'
require_dependency 'suggested_topics_builder'
require_dependency 'topic_query_sql'

class TopicQuery
  # Could be rewritten to %i if Ruby 1.9 is no longer supported
  VALID_OPTIONS = %w(except_topic_ids
                     exclude_category
                     limit
                     page
                     per_page
                     min_posts
                     max_posts
                     topic_ids
                     visible
                     category
                     order
                     ascending
                     no_subcategories
                     no_definitions
                     status
                     search
                     ).map(&:to_sym)

  # Maps `order` to a columns in `topics`
  SORTABLE_MAPPING = {
    'likes' => 'like_count',
    'views' => 'views',
    'posts' => 'posts_count',
    'activity' => 'created_at',
    'posters' => 'participant_count',
    'category' => 'category_id'
  }

  def initialize(user=nil, options={})
    options.assert_valid_keys(VALID_OPTIONS)
    @options = options
    @user = user
  end

  def joined_topic_user(list=nil)
    (list || Topic).joins("LEFT OUTER JOIN topic_users AS tu ON (topics.id = tu.topic_id AND tu.user_id = #{@user.id.to_i})")
  end

  # Return a list of suggested topics for a topic
  def list_suggested_for(topic)
    builder = SuggestedTopicsBuilder.new(topic)

    # When logged in we start with different results
    if @user
      builder.add_results(unread_results(topic: topic, per_page: builder.results_left), :high)
      builder.add_results(new_results(topic: topic, per_page: builder.category_results_left), :high) unless builder.category_full?
    end
    builder.add_results(random_suggested(topic, builder.results_left, builder.excluded_topic_ids), :low) unless builder.full?

    create_list(:suggested, {}, builder.results)
  end

  # The latest view of topics
  def list_latest
    TopicList.new(:latest, @user, latest_results)
  end

  # The starred topics
  def list_starred
    create_list(:starred) {|topics| topics.where('tu.starred') }
  end

  def list_read
    create_list(:read, unordered: true) do |topics|
      topics.order('COALESCE(tu.last_visited_at, topics.bumped_at) DESC')
    end
  end

  def list_new
    TopicList.new(:new, @user, new_results)
  end

  def list_unread
    TopicList.new(:new, @user, unread_results)
  end

  def list_posted
    create_list(:posted) {|l| l.where('tu.posted') }
  end

  def list_top_for(period)
    score = "#{period}_score"
    create_list(:top, unordered: true) do |topics|
      topics = topics.joins(:top_topic).where("top_topics.#{score} > 0")
      if period == :yearly && @user.try(:trust_level) == TrustLevel.levels[:newuser]
        topics.order(TopicQuerySQL.order_top_with_pinned_category_for(score))
      else
        topics.order(TopicQuerySQL.order_top_for(score))
      end
    end
  end

  def list_topics_by(user)
    create_list(:user_topics) do |topics|
      topics.where(user_id: user.id)
    end
  end

  def list_private_messages(user)
    list = private_messages_for(user)
    TopicList.new(:private_messages, user, list)
  end

  def list_private_messages_sent(user)
    list = private_messages_for(user)
    list = list.where(user_id: user.id)
    TopicList.new(:private_messages, user, list)
  end

  def list_private_messages_unread(user)
    list = private_messages_for(user)
    list = list.where("tu.last_read_post_number IS NULL OR tu.last_read_post_number < topics.highest_post_number")
    TopicList.new(:private_messages, user, list)
  end

  def list_category(category)
    create_list(:category, unordered: true, category: category.id) do |list|
      if @user
        list.order(TopicQuerySQL.order_with_pinned_sql)
      else
        list.order(TopicQuerySQL.order_basic_bumped)
      end
    end
  end

  def list_new_in_category(category)
    create_list(:new_in_category, unordered: true, category: category.id) do |list|
      list.by_newest.first(25)
    end
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

  protected

    def create_list(filter, options={}, topics = nil)
      topics ||= default_results(options)
      topics = yield(topics) if block_given?
      TopicList.new(filter, @user, topics)
    end

    def private_messages_for(user)
      options = @options
      options.reverse_merge!(per_page: SiteSetting.topics_per_page)

      # Start with a list of all topics
      result = Topic.includes(:allowed_users)
                    .where("topics.id IN (SELECT topic_id FROM topic_allowed_users WHERE user_id = #{user.id.to_i})")
                    .joins("LEFT OUTER JOIN topic_users AS tu ON (topics.id = tu.topic_id AND tu.user_id = #{user.id.to_i})")
                    .order(TopicQuerySQL.order_nocategory_basic_bumped)
                    .private_messages

      result = result.limit(options[:per_page]) unless options[:limit] == false
      result = result.visible if options[:visible] || @user.nil? || @user.regular?
      result = result.offset(options[:page].to_i * options[:per_page]) if options[:page]
      result
    end

    def default_ordering(result, options)
      # If we're logged in, we have to pay attention to our pinned settings
      if @user
        result = options[:category].blank? ? result.order(TopicQuerySQL.order_nocategory_with_pinned_sql) :
                                             result.order(TopicQuerySQL.order_with_pinned_sql)
      else
        result = options[:category].blank? ? result.order(TopicQuerySQL.order_nocategory_basic_bumped) :
                                             result.order(TopicQuerySQL.order_basic_bumped)
      end
      result
    end

    def apply_ordering(result, options)
      sort_column = SORTABLE_MAPPING[options[:order]] || 'default'
      sort_dir = (options[:ascending] == "true") ? "ASC" : "DESC"

      # If we are sorting in the default order desc, we should consider including pinned
      # topics. Otherwise, just use bumped_at.
      if sort_column == 'default'
        if sort_dir == 'DESC'
          # If something requires a custom order, for example "unread" which sorts the least read
          # to the top, do nothing
          return result if options[:unordered]
          # Otherwise apply our default ordering
          return default_ordering(result, options)
        end
        sort_column = 'bumped_at'
      end

      # If we are sorting by category, actually use the name
      if sort_column == 'category_id'
        return result.references(:categories).order(TopicQuerySQL.order_by_category_sql(sort_dir))
      end

      result.order("topics.#{sort_column} #{sort_dir}")
    end

    def get_category_id(category_id_or_slug)
      return nil unless category_id_or_slug
      category_id = category_id_or_slug.to_i
      category_id = Category.where(slug: category_id_or_slug).pluck(:id).first if category_id == 0
      category_id
    end


    # Create results based on a bunch of default options
    def default_results(options={})
      options.reverse_merge!(@options)
      options.reverse_merge!(per_page: SiteSetting.topics_per_page)

      # Start with a list of all topics
      result = Topic

      if @user
        result = result.joins("LEFT OUTER JOIN topic_users AS tu ON (topics.id = tu.topic_id AND tu.user_id = #{@user.id.to_i})")
                       .references('tu')
      end

      category_id = get_category_id(options[:category])
      if category_id
        if options[:no_subcategories]
          result = result.where('categories.id = ?', category_id)
        else
          result = result.where('categories.id = ? or (categories.parent_category_id = ? AND categories.topic_id <> topics.id)', category_id, category_id)
        end
        result = result.references(:categories)
      end

      result = apply_ordering(result, options)
      result = result.listable_topics.includes(category: :topic_only_relative_url)
      result = result.where('categories.name is null or categories.name <> ?', options[:exclude_category]).references(:categories) if options[:exclude_category]

      # Don't include the category topics if excluded
      if options[:no_definitions]
        result = result.where('COALESCE(categories.topic_id, 0) <> topics.id')
      end

      result = result.limit(options[:per_page]) unless options[:limit] == false
      result = result.visible if options[:visible] || @user.nil? || @user.regular?
      result = result.where.not(topics: {id: options[:except_topic_ids]}).references(:topics) if options[:except_topic_ids]
      result = result.offset(options[:page].to_i * options[:per_page]) if options[:page]

      if options[:topic_ids]
        result = result.where('topics.id in (?)', options[:topic_ids]).references(:topics)
      end

      if search = options[:search]
        result = result.where("topics.id in (select pp.topic_id from post_search_data pd join posts pp on pp.id = pd.post_id where pd.search_data @@ #{Search.ts_query(search.to_s)})")
      end

      if status = options[:status]
        case status
        when 'open'
          result = result.where('NOT topics.closed AND NOT topics.archived')
        when 'closed'
          result = result.where('topics.closed')
        when 'archived'
          result = result.where('topics.archived')
        end
      end

      result = result.where('topics.posts_count <= ?', options[:max_posts]) if options[:max_posts].present?
      result = result.where('topics.posts_count >= ?', options[:min_posts]) if options[:min_posts].present?

      guardian = Guardian.new(@user)
      if !guardian.is_admin?
        allowed_ids = guardian.allowed_category_ids
        if allowed_ids.length > 0
          result = result.where('topics.category_id IS NULL or topics.category_id IN (?)', allowed_ids)
        else
          result = result.where('topics.category_id IS NULL')
        end
        result = result.references(:categories)
      end

      result
    end

    def latest_results(options={})
      result = default_results(options)
      result = remove_muted_categories(result, @user, exclude: options[:category])
      result
    end

    def remove_muted_categories(list, user, opts)
      category_id = get_category_id(opts[:exclude]) if opts
      if user
        list = list.where("NOT EXISTS(
                         SELECT 1 FROM category_users cu
                         WHERE cu.user_id = ? AND
                               cu.category_id = topics.category_id AND
                               cu.notification_level = ? AND
                               cu.category_id <> ?
                         )",
                          user.id,
                          CategoryUser.notification_levels[:muted],
                          category_id || -1
                         )
                      .references('cu')
      end

      list
    end


    def unread_results(options={})
      result = TopicQuery.unread_filter(default_results(options.reverse_merge(:unordered => true)))
                         .order('CASE WHEN topics.user_id = tu.user_id THEN 1 ELSE 2 END')

      suggested_ordering(result, options)
    end

    def new_results(options={})
      result = TopicQuery.new_filter(default_results(options.reverse_merge(:unordered => true)), @user.treat_as_new_topic_start_date)
      result = remove_muted_categories(result, @user, exclude: options[:category])
      suggested_ordering(result, options)
    end

    def random_suggested(topic, count, excluded_topic_ids=[])
      result = default_results(unordered: true, per_page: count).where(closed: false, archived: false)
      excluded_topic_ids += Category.pluck(:topic_id).compact
      result = result.where("topics.id NOT IN (?)", excluded_topic_ids) unless excluded_topic_ids.empty?

      # If we are in a category, prefer it for the random results
      if topic.category_id
        result = result.order("CASE WHEN topics.category_id = #{topic.category_id.to_i} THEN 0 ELSE 1 END")
      end

      result.order("RANDOM()")
    end

    def suggested_ordering(result, options)
      # Prefer unread in the same category
      if options[:topic] && options[:topic].category_id
        result = result.order("CASE WHEN topics.category_id = #{options[:topic].category_id.to_i} THEN 0 ELSE 1 END")
      end

      result.order(TopicQuerySQL.order_nocategory_with_pinned_sql)
    end
end
