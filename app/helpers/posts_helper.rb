# frozen_string_literal: true

module PostsHelper
  include ApplicationHelper

  CACHE_URL_DURATION = 12.hours.to_i

  def self.clear_canonical_cache!(post)
    key = canonical_redis_key(post)
    Discourse.redis.del(key)
  end

  def self.canonical_redis_key(post)
    "post_canonical_url_#{post.id}"
  end

  def cached_post_url(post, use_canonical:)
    if use_canonical
      # this is very expensive to calculate page, we cache it for 12 hours
      key = PostsHelper.canonical_redis_key(post)

      url = Discourse.redis.get(key)

      # break cache if either slug or topic_id changes
      url = nil if url && !url.start_with?(post.topic.url)

      if !url
        url = post.canonical_url
        Discourse.redis.setex(key, CACHE_URL_DURATION, url)
      end

      url
    else
      post.full_url
    end
  end
end
