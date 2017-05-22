class TopicTimestampChanger
  class InvalidTimestampError < StandardError; end

  def initialize(timestamp:, topic: nil, topic_id: nil)
    @topic = topic || Topic.with_deleted.find(topic_id)
    @posts = @topic.posts
    @current_timestamp = Time.zone.now
    @timestamp = Time.zone.at(timestamp)

    raise InvalidTimestampError if @timestamp.to_f > @current_timestamp.to_f

    @time_difference = calculate_time_difference
  end

  def change!
    ActiveRecord::Base.transaction do
      last_posted_at = @timestamp

      @posts.each do |post|
        if post.is_first_post?
          update_post(post, @timestamp)
        else
          new_created_at = Time.at(post.created_at.to_f + @time_difference)
          new_created_at = @current_timestamp if new_created_at > @current_timestamp
          last_posted_at = new_created_at if new_created_at > last_posted_at
          update_post(post, new_created_at)
        end
      end

      update_topic(last_posted_at)

      yield(@topic) if block_given?
    end

    # Burst the cache for stats
    [AdminDashboardData, About].each { |klass| $redis.del klass.stats_cache_key }
  end

  private

  def calculate_time_difference
    @timestamp - @topic.created_at
  end

  def update_topic(last_posted_at)
    @topic.update_attributes(
      created_at: @timestamp,
      updated_at: @timestamp,
      bumped_at: @timestamp,
      last_posted_at: last_posted_at
    )
  end

  def update_post(post, timestamp)
    post.update_attributes(created_at: timestamp, updated_at: timestamp)
  end
end
