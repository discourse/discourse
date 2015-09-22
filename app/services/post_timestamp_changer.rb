class PostTimestampChanger
  def initialize(params)
    @topic = Topic.with_deleted.find(params[:topic_id])
    @posts = @topic.posts
    @timestamp = Time.at(params[:timestamp])
    @time_difference = calculate_time_difference
  end

  def change!
    ActiveRecord::Base.transaction do
      update_topic

      @posts.each do |post|
        if post.is_first_post?
          update_post(post, @timestamp)
        else
          update_post(post, Time.at(post.created_at.to_f + @time_difference))
        end
      end
    end

    # Burst the cache for stats
    [AdminDashboardData, About].each { |klass| $redis.del klass.stats_cache_key }
  end

  private

  def calculate_time_difference
    @timestamp - @topic.created_at
  end

  def update_topic
    @topic.update_attributes(
      created_at: @timestamp,
      updated_at: @timestamp,
      bumped_at: @timestamp
    )
  end

  def update_post(post, timestamp)
    post.update_attributes(created_at: timestamp, updated_at: timestamp)
  end
end
