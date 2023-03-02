# frozen_string_literal: true

class TopicRetriever
  def initialize(embed_url, opts = nil)
    @embed_url = embed_url
    @opts = opts || {}
  end

  def retrieve
    perform_retrieve unless (invalid_url? || retrieved_recently?)
  end

  private

  def invalid_url?
    !EmbeddableHost.url_allowed?(@embed_url.strip)
  end

  def retrieved_recently?
    # We can disable the throttle for some users, such as staff
    return false if @opts[:no_throttle]

    # Throttle other users to once every 60 seconds
    retrieved_key = "retrieved_topic"
    if Discourse.redis.setnx(retrieved_key, "1")
      Discourse.redis.expire(retrieved_key, 60)
      return false
    end

    true
  end

  def perform_retrieve
    # It's possible another process or job found the embed already. So if that happened bail out.
    return if TopicEmbed.where(embed_url: @embed_url).exists?

    if @opts[:author_username].present?
      Discourse.deprecate(
        "discourse_username parameter has been deprecated. Prefer passing author name using a <meta> tag.",
        since: "3.1.0.beta1",
        drop_from: "3.2",
      )
    end

    username =
      @opts[:author_username].presence || SiteSetting.embed_by_username.presence ||
        SiteSetting.site_contact_username.presence || Discourse.system_user.username

    TopicEmbed.import_remote(@embed_url, user: User.find_by(username_lower: username.downcase))
  end
end
