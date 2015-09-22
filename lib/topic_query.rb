#
# Helps us find topics.
# Returns a TopicList object containing the topics found.
#

require_dependency 'topic_list'
require_dependency 'suggested_topics_builder'
require_dependency 'topic_query_sql'

class TopicQuery
  # Could be rewritten to %i if Ruby 1.9 is no longer supported
  VALID_OPTIONS = %i(except_topic_ids
                     exclude_category_ids
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
                     state
                     search
                     slow_platform
                     filter
                     q)

  # Maps `order` to a columns in `topics`
  SORTABLE_MAPPING = {
    'likes' => 'like_count',
    'op_likes' => 'op_likes',
    'views' => 'views',
    'posts' => 'posts_count',
    'activity' => 'bumped_at',
    'posters' => 'participant_count',
    'category' => 'category_id',
    'created' => 'created_at'
  }

  def initialize(user=nil, options={})
    options.assert_valid_keys(VALID_OPTIONS)
    @options = options.dup
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
      builder.add_results(new_results(topic: topic, per_page: builder.category_results_left)) unless builder.full?
    end
    builder.add_results(random_suggested(topic, builder.results_left, builder.excluded_topic_ids)) unless builder.full?

    create_list(:suggested, {unordered: true}, builder.results)
  end

  # The latest view of topics
  def list_latest
    create_list(:latest, {}, latest_results)
  end

  def list_read
    create_list(:read, unordered: true) do |topics|
      topics.order('COALESCE(tu.last_visited_at, topics.bumped_at) DESC')
    end
  end

  def list_new
    create_list(:new, {unordered: true}, new_results)
  end

  def list_unread
    create_list(:unread, {unordered: true}, unread_results)
  end

  def list_posted
    create_list(:posted) {|l| l.where('tu.posted') }
  end

  def list_bookmarks
    create_list(:bookmarks) {|l| l.where('tu.bookmarked') }
  end

  def list_top_for(period)
    score = "#{period}_score"
    create_list(:top, unordered: true) do |topics|
      topics = topics.joins(:top_topic).where("top_topics.#{score} > 0")
      if period == :yearly && @user.try(:trust_level) == TrustLevel[0]
        topics.order(TopicQuerySQL.order_top_with_pinned_category_for(score))
      else
        topics.order(TopicQuerySQL.order_top_for(score))
      end
    end
  end

  def list_topics_by(user)
    @options[:filtered_to_user] = user.id
    create_list(:user_topics) do |topics|
      topics.where(user_id: user.id)
    end
  end

  def list_private_messages(user)
    list = private_messages_for(user)
    create_list(:private_messages, {}, list)
  end

  def list_private_messages_sent(user)
    list = private_messages_for(user)
    list = list.where(user_id: user.id)
    create_list(:private_messages, {}, list)
  end

  def list_private_messages_unread(user)
    list = private_messages_for(user)
    list = list.where("tu.last_read_post_number IS NULL OR tu.last_read_post_number < topics.highest_post_number")
    create_list(:private_messages, {}, list)
  end

  def list_category_topic_ids(category)
    query = default_results(category: category.id)
    pinned_ids = query.where('pinned_at IS NOT NULL AND category_id = ?', category.id)
                      .limit(nil)
                      .order('pinned_at DESC').pluck(:id)
    non_pinned_ids = query.where('pinned_at IS NULL OR category_id <> ?', category.id).pluck(:id)
    (pinned_ids + non_pinned_ids)
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

  def prioritize_pinned_topics(topics, options)

    pinned_clause = options[:category_id] ? "topics.category_id = #{options[:category_id].to_i} AND" : "pinned_globally AND "
    pinned_clause << " pinned_at IS NOT NULL "
    if @user
      pinned_clause << " AND (topics.pinned_at > tu.cleared_pinned_at OR tu.cleared_pinned_at IS NULL)"
    end

    unpinned_topics = topics.where("NOT ( #{pinned_clause} )")
    pinned_topics = topics.dup.offset(nil).where(pinned_clause)

    per_page = options[:per_page] || per_page_setting
    limit = per_page unless options[:limit] == false
    page = options[:page].to_i

    if page == 0
      (pinned_topics + unpinned_topics)[0...limit] if limit
    else
      offset = (page * per_page) - pinned_topics.count - 1
      offset = 0 unless offset > 0
      unpinned_topics.offset(offset).to_a
    end

  end

  def create_list(filter, options={}, topics = nil)
    topics ||= default_results(options)
    topics = yield(topics) if block_given?

    options = options.merge(@options)
    if (options[:order] || "activity") == "activity" && !options[:unordered]
      topics = prioritize_pinned_topics(topics, options)
    end

    topics = topics.to_a.each do |t|
      t.allowed_user_ids = filter == :private_messages ? t.allowed_users.map{|u| u.id} : []
    end

    list = TopicList.new(filter, @user, topics.to_a, options.merge(@options))
    list.per_page = per_page_setting
    list
  end

  def latest_results(options={})
    result = default_results(options)
    result = remove_muted_categories(result, @user, exclude: options[:category])
    result
  end

  def unread_results(options={})
    result = TopicQuery.unread_filter(default_results(options.reverse_merge(:unordered => true)))
    .order('CASE WHEN topics.user_id = tu.user_id THEN 1 ELSE 2 END')
    suggested_ordering(result, options)
  end

  def new_results(options={})
    # TODO does this make sense or should it be ordered on created_at
    #  it is ordering on bumped_at now
    result = TopicQuery.new_filter(default_results(options.reverse_merge(:unordered => true)), @user.treat_as_new_topic_start_date)
    result = remove_muted_categories(result, @user, exclude: options[:category])
    suggested_ordering(result, options)
  end

  protected

    def per_page_setting
      @options[:slow_platform] ? 15 : 30
    end


    def private_messages_for(user)
      options = @options
      options.reverse_merge!(per_page: per_page_setting)

      # Start with a list of all topics
      result = Topic.includes(:allowed_users)
                    .where("topics.id IN (SELECT topic_id FROM topic_allowed_users WHERE user_id = #{user.id.to_i})")
                    .joins("LEFT OUTER JOIN topic_users AS tu ON (topics.id = tu.topic_id AND tu.user_id = #{user.id.to_i})")
                    .order("topics.bumped_at DESC")
                    .private_messages

      result = result.limit(options[:per_page]) unless options[:limit] == false
      result = result.visible if options[:visible] || @user.nil? || @user.regular?
      result = result.offset(options[:page].to_i * options[:per_page]) if options[:page]
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
        end
        sort_column = 'bumped_at'
      end

      # If we are sorting by category, actually use the name
      if sort_column == 'category_id'
        # TODO forces a table scan, slow
        return result.references(:categories).order(TopicQuerySQL.order_by_category_sql(sort_dir))
      end

      if sort_column == 'op_likes'
        return result.includes(:first_post).order("(SELECT like_count FROM posts p3 WHERE p3.topic_id = topics.id AND p3.post_number = 1) #{sort_dir}")
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
      options.reverse_merge!(per_page: per_page_setting)

      # Whether to return visible topics
      options[:visible] = true if @user.nil? || @user.regular?
      options[:visible] = false if @user && @user.id == options[:filtered_to_user]

      # Start with a list of all topics
      result = Topic.unscoped

      if @user
        result = result.joins("LEFT OUTER JOIN topic_users AS tu ON (topics.id = tu.topic_id AND tu.user_id = #{@user.id.to_i})")
                       .references('tu')
      end

      category_id = get_category_id(options[:category])
      @options[:category_id] = category_id
      if category_id
        if options[:no_subcategories]
          result = result.where('categories.id = ?', category_id)
        else
          result = result.where('categories.id = :category_id OR (categories.parent_category_id = :category_id AND categories.topic_id <> topics.id)', category_id: category_id)
        end
        result = result.references(:categories)
      end

      result = apply_ordering(result, options)
      result = result.listable_topics.includes(:category)

      if options[:exclude_category_ids] && options[:exclude_category_ids].is_a?(Array) && options[:exclude_category_ids].size > 0
        result = result.where("categories.id NOT IN (?)", options[:exclude_category_ids]).references(:categories)
      end

      # Don't include the category topics if excluded
      if options[:no_definitions]
        result = result.where('COALESCE(categories.topic_id, 0) <> topics.id')
      end

      result = result.limit(options[:per_page]) unless options[:limit] == false

      result = result.visible if options[:visible]
      result = result.where.not(topics: {id: options[:except_topic_ids]}).references(:topics) if options[:except_topic_ids]
      result = result.offset(options[:page].to_i * options[:per_page]) if options[:page]

      if options[:topic_ids]
        result = result.where('topics.id in (?)', options[:topic_ids]).references(:topics)
      end

      if search = options[:search]
        result = result.where("topics.id in (select pp.topic_id from post_search_data pd join posts pp on pp.id = pd.post_id where pd.search_data @@ #{Search.ts_query(search.to_s)})")
      end

      # NOTE protect against SYM attack can be removed with Ruby 2.2
      #
      state = options[:state]
      if @user && state &&
          TopicUser.notification_levels.keys.map(&:to_s).include?(state)
        level = TopicUser.notification_levels[state.to_sym]
        result = result.where('topics.id IN (
                                  SELECT topic_id
                                  FROM topic_users
                                  WHERE user_id = ? AND
                                        notification_level = ?)', @user.id, level)
      end

      require_deleted_clause = true
      if status = options[:status]
        case status
        when 'open'
          result = result.where('NOT topics.closed AND NOT topics.archived')
        when 'closed'
          result = result.where('topics.closed')
        when 'archived'
          result = result.where('topics.archived')
        when 'listed'
          result = result.where('topics.visible')
        when 'unlisted'
          result = result.where('NOT topics.visible')
        when 'deleted'
          guardian = Guardian.new(@user)
          if guardian.is_staff?
            result = result.where('topics.deleted_at IS NOT NULL')
            require_deleted_clause = false
          end
        end
      end

      if (filter=options[:filter]) && @user
        action =
          if filter == "bookmarked"
            PostActionType.types[:bookmark]
          elsif filter == "liked"
            PostActionType.types[:like]
          end
        if action
          result = result.where('topics.id IN (SELECT pp.topic_id
                                FROM post_actions pa
                                JOIN posts pp ON pp.id = pa.post_id
                                WHERE pa.user_id = :user_id AND
                                      pa.post_action_type_id = :action AND
                                      pa.deleted_at IS NULL
                             )', user_id: @user.id,
                                 action: action
                             )
        end
      end

      result = result.where('topics.deleted_at IS NULL') if require_deleted_clause
      result = result.where('topics.posts_count <= ?', options[:max_posts]) if options[:max_posts].present?
      result = result.where('topics.posts_count >= ?', options[:min_posts]) if options[:min_posts].present?

      Guardian.new(@user).filter_allowed_categories(result)
    end

    def remove_muted_categories(list, user, opts=nil)
      category_id = get_category_id(opts[:exclude]) if opts

      if user
        list = list.references("cu")
                   .where("
          NOT EXISTS (
            SELECT 1
              FROM category_users cu
             WHERE cu.user_id = :user_id
               AND cu.category_id = topics.category_id
               AND cu.notification_level = :muted
               AND cu.category_id <> :category_id
          )", user_id: user.id,
              muted: CategoryUser.notification_levels[:muted],
              category_id: category_id || -1)
      end

      list
    end


    def random_suggested(topic, count, excluded_topic_ids=[])
      result = default_results(unordered: true, per_page: count).where(closed: false, archived: false)
      excluded_topic_ids += Category.pluck(:topic_id).compact
      result = result.where("topics.id NOT IN (?)", excluded_topic_ids) unless excluded_topic_ids.empty?

      result = remove_muted_categories(result, @user)

      # If we are in a category, prefer it for the random results
      if topic.category_id
        result = result.order("CASE WHEN topics.category_id = #{topic.category_id.to_i} THEN 0 ELSE 1 END")
      end

      # Best effort, it over selects, however if you have a high number
      # of muted categories there is tiny chance we will not select enough
      # in particular this can happen if current category is empty and tons
      # of muted, big edge case
      #
      # we over select in case cache is stale
      max = (count*1.3).to_i
      ids = RandomTopicSelector.next(max) + RandomTopicSelector.next(max, topic.category)

      result.where(id: ids.uniq)
    end

    def suggested_ordering(result, options)
      # Prefer unread in the same category
      if options[:topic] && options[:topic].category_id
        result = result.order("CASE WHEN topics.category_id = #{options[:topic].category_id.to_i} THEN 0 ELSE 1 END")
      end

      result.order('topics.bumped_at DESC')
    end
end
