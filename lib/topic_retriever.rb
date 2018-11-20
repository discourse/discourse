class TopicRetriever

  def initialize(embed_url, opts = nil)
    @embed_url = embed_url
    @author_username = opts[:author_username]
    @opts = opts || {}
  end

  def retrieve
    perform_retrieve unless (invalid_url? || retrieved_recently?)
  end

  private

  def invalid_url?
    !EmbeddableHost.url_allowed?(@embed_url)
  end

  def retrieved_recently?
    # We can disable the throttle for some users, such as staff
    return false if @opts[:no_throttle]

    # Throttle other users to once every 60 seconds
    retrieved_key = "retrieved_topic"
    if $redis.setnx(retrieved_key, "1")
      $redis.expire(retrieved_key, 60)
      return false
    end

    true
  end

  def perform_retrieve
    # It's possible another process or job found the embed already. So if that happened bail out.
    return if TopicEmbed.where(embed_url: @embed_url).exists?

    # First check RSS if that is enabled
    if SiteSetting.feed_polling_enabled?
      Jobs::PollFeed.new.execute({})
      return if TopicEmbed.where(embed_url: @embed_url).exists?
    end

    fetch_http
  end

  def fetch_http
    if @author_username.nil?
      username = SiteSetting.embed_by_username.downcase
    else
      username = @author_username
    end

    user = User.where(username_lower: username.downcase).first
    return if user.blank?

    TopicEmbed.import_remote(user, @embed_url)
  end

end
