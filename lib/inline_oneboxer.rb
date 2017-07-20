class InlineOneboxer

  def initialize(urls)
    @urls = urls
  end

  def process
    @urls.map {|url| InlineOneboxer.lookup(url) }.compact
  end

  def self.clear_cache!
  end

  def self.cache_lookup(url)
    Rails.cache.read(cache_key(url))
  end

  def self.lookup(url)
    cached = cache_lookup(url)
    return cached if cached.present?

    if route = Discourse.route_for(url)
      if route[:controller] == "topics" &&
        route[:action] == "show" &&
        topic = (Topic.where(id: route[:topic_id].to_i).first rescue nil)

        # Only public topics
        if Guardian.new.can_see?(topic)
          onebox = { url: url, title: topic.title }
          Rails.cache.write(cache_key(url), onebox, expires_in: 1.day)
          return onebox
        end
      end
    end

    nil
  end

  private

    def self.cache_key(url)
      "inline_onebox:#{url}"
    end

end

