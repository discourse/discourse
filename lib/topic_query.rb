# 
# Helps us find topics. Returns a TopicList object containing the topics
# found.
#
require_dependency 'topic_list'

class TopicQuery

  def initialize(user=nil, opts={})
    @user = user 

    # Cast to int to avoid sql injection
    @user_id = user.id.to_i if @user.present?

    @opts = opts
  end

  # Return a list of suggested topics for a topic
  def list_suggested_for(topic)   

    exclude_topic_ids = [topic.id]

    # If not logged in, return some random results, preferably in this category
    if @user.blank?
      return TopicList.new(@user, random_suggested_results_for(topic, SiteSetting.suggested_topics, exclude_topic_ids))
    end

    results = unread_results(per_page: SiteSetting.suggested_topics).where('topics.id NOT IN (?)', exclude_topic_ids).all
    results_left = SiteSetting.suggested_topics - results.size

    # If we don't have enough results, go to new posts
    if results_left > 0
      exclude_topic_ids << results.map {|t| t.id}
      exclude_topic_ids.flatten!

      results << new_results(per_page: results_left).where('topics.id NOT IN (?)', exclude_topic_ids).all
      results.flatten!

      results_left = SiteSetting.suggested_topics - results.size

      # If we STILL don't have enough results, find random topics
      if results_left > 0
        exclude_topic_ids << results.map {|t| t.id}
        exclude_topic_ids.flatten!

        results << random_suggested_results_for(topic, results_left, exclude_topic_ids).all
        results.flatten!
      end
    end

    TopicList.new(@user, results)
  end

  # The popular view of topics
  def list_popular
    return_list(unordered: true) do |list|
      list.order('CASE WHEN topics.category_id IS NULL and topics.pinned THEN 0 ELSE 1 END, topics.bumped_at DESC')
    end
  end

  # The favorited topics
  def list_favorited
    return_list do |list|
      list.joins("INNER JOIN topic_users AS tu ON (topics.id = tu.topic_id AND tu.starred AND tu.user_id = #{@user_id})")
    end   
  end

  def list_read
    return_list(unordered: true) do |list|
      list
        .joins("INNER JOIN topic_users AS tu ON (topics.id = tu.topic_id AND tu.user_id = #{@user_id})")
        .order('COALESCE(tu.last_visited_at, topics.bumped_at) DESC')
    end
  end

  def list_new
    TopicList.new(@user, new_results)
  end

  def list_unread
    TopicList.new(@user, unread_results)
  end

  def list_posted
    return_list do |list|
      list.joins("INNER JOIN topic_users AS tu ON (tu.topic_id = topics.id AND tu.posted AND tu.user_id = #{@user_id})")
    end
  end

  def list_uncategorized
    return_list {|l| l.where(category_id: nil).order('topics.pinned desc')}
  end

  def list_category(category)
    return_list {|l| l.where(category_id: category.id).order('topics.pinned desc')}
  end

  def unread_count
    unread_results(limit: false).count
  end

  def new_count
    new_results(limit: false).count
  end

  protected

    def return_list(list_opts={})
      TopicList.new(@user, yield(default_list(list_opts)))      
    end

    # Create a list based on a bunch of detault options
    def default_list(list_opts={})

      query_opts = @opts.merge(list_opts)
      page_size = query_opts[:per_page] || SiteSetting.topics_per_page

      result = Topic
      result = result.topic_list_order unless query_opts[:unordered] 
      result = result.listable_topics.includes(:category)    
      result = result.where('categories.name is null or categories.name <> ?', query_opts[:exclude_category]) if query_opts[:exclude_category]
      result = result.where('categories.name = ?', query_opts[:only_category]) if query_opts[:only_category]
      result = result.limit(page_size) unless query_opts[:limit] == false 
      result = result.visible if @user.blank? or @user.regular?
      result = result.where('topics.id <> ?', query_opts[:except_topic_id]) if query_opts[:except_topic_id].present?    
      result = result.offset(query_opts[:page].to_i * page_size) if query_opts[:page].present?
      result      
    end

    def new_results(list_opts={})
      date = @user.previous_visit_at
      date = @user.created_at unless date

      default_list(list_opts)
        .joins("LEFT OUTER JOIN topic_users AS tu ON (topics.id = tu.topic_id AND tu.user_id = #{@user_id})")
        .where("topics.created_at >= :created_at", created_at: date)
        .where("tu.last_read_post_number IS NULL")
        .where("COALESCE(tu.notification_level, :tracking) >= :tracking", tracking: TopicUser::NotificationLevel::TRACKING)
    end

    def unread_results(list_opts={})
      default_list(list_opts)
        .joins("INNER JOIN topic_users AS tu ON (topics.id = tu.topic_id AND tu.user_id = #{@user_id} AND tu.last_read_post_number < topics.highest_post_number)")
        .where("COALESCE(tu.notification_level, :regular) >= :tracking", regular: TopicUser::NotificationLevel::REGULAR, tracking: TopicUser::NotificationLevel::TRACKING)
    end

    def random_suggested_results_for(topic, count, exclude_topic_ids)
      results = default_list(unordered: true, per_page: count)
                 .where('topics.id NOT IN (?)', exclude_topic_ids)
                 .order('RANDOM()')

      results = results.where('category_id = ?', topic.category_id) if topic.category_id.present?    
      results
    end

end
