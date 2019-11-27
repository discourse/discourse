# frozen_string_literal: true

class InlineOneboxer

  MIN_TITLE_LENGTH = 2

  def initialize(urls, opts = nil)
    @urls = urls
    @opts = opts || {}
  end

  def process
    @urls.map { |url| InlineOneboxer.lookup(url, @opts) }.compact
  end

  def self.purge(url)
    Discourse.cache.delete(cache_key(url))
  end

  def self.cache_lookup(url)
    Discourse.cache.read(cache_key(url))
  end

  def self.lookup(url, opts = nil)
    opts ||= {}
    opts = opts.with_indifferent_access

    unless opts[:skip_cache] || opts[:invalidate]
      cached = cache_lookup(url)
      return cached if cached.present?
    end

    return unless url

    if route = Discourse.route_for(url)
      if route[:controller] == "topics" &&
        route[:action] == "show" &&
        topic = Topic.where(id: route[:topic_id].to_i).first

        return onebox_for(url, topic.title, opts) if Guardian.new.can_see?(topic)
      end
    end

    always_allow = SiteSetting.enable_inline_onebox_on_all_domains
    domains = SiteSetting.inline_onebox_domains_whitelist&.split('|') unless always_allow

    if always_allow || domains
      uri = begin
        URI(url)
      rescue URI::Error
      end

      if uri.present? &&
        uri.hostname.present? &&
        (always_allow || domains.include?(uri.hostname))
        title = RetrieveTitle.crawl(url)
        title = nil if title && title.length < MIN_TITLE_LENGTH
        return onebox_for(url, title, opts)
      end
    end

    nil
  end

  private

  def self.onebox_for(url, title, opts)
    onebox = {
      url: url,
      title: title && Emoji.gsub_emoji_to_unicode(title)
    }
    unless opts[:skip_cache]
      Discourse.cache.write(cache_key(url), onebox, expires_in: 1.day)
    end

    onebox
  end

  def self.cache_key(url)
    "inline_onebox:#{url}"
  end

end
