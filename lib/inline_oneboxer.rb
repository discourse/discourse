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

  def self.invalidate(url)
    Discourse.cache.delete(cache_key(url))
  end

  def self.cache_lookup(url)
    Discourse.cache.read(cache_key(url))
  end

  def self.local_handlers
    @local_handlers ||= {}
  end

  def self.register_local_handler(controller, &handler)
    local_handlers[controller] = handler
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
      if route[:controller] == "topics"
        if topic = Oneboxer.local_topic(url, route, opts)
          opts[:skip_cache] = true
          post_number = [route[:post_number].to_i, topic.highest_post_number].min
          if post_number > 1
            opts[:post_number] = post_number
            opts[:post_author] = post_author_for_title(topic, post_number)
          end
          return onebox_for(url, topic.title, opts)
        else
          # not permitted to see topic
          return nil
        end
      elsif handler = local_handlers[route[:controller]]
        return handler.call(url, route)
      end
    end

    always_allow = SiteSetting.enable_inline_onebox_on_all_domains
    allowed_domains = SiteSetting.allowed_inline_onebox_domains&.split("|") unless always_allow

    if always_allow || allowed_domains
      uri =
        begin
          URI(url)
        rescue URI::Error
        end

      if uri.present? && uri.hostname.present? &&
           (always_allow || allowed_domains.include?(uri.hostname)) &&
           !Onebox::DomainChecker.is_blocked?(uri.hostname)
        max_redirects = 0 if SiteSetting.block_onebox_on_redirect
        title =
          RetrieveTitle.crawl(
            url,
            max_redirects: max_redirects,
            initial_https_redirect_ignore_limit: SiteSetting.block_onebox_on_redirect,
            headers: {
              "Accept-Language" => Oneboxer.accept_language,
            },
          )
        title = nil if title && title.length < MIN_TITLE_LENGTH
        return onebox_for(url, title, opts)
      end
    end

    nil
  end

  private

  def self.onebox_for(url, title, opts)
    title = title && Emoji.gsub_emoji_to_unicode(title)
    if title && opts[:post_number]
      title += " - "
      if opts[:post_author]
        title +=
          I18n.t(
            "inline_oneboxer.topic_page_title_post_number_by_user",
            post_number: opts[:post_number],
            username: opts[:post_author],
          )
      else
        title +=
          I18n.t("inline_oneboxer.topic_page_title_post_number", post_number: opts[:post_number])
      end
    end

    title = title && Emoji.gsub_emoji_to_unicode(title)
    title = WordWatcher.censor_text(title) if title.present?

    onebox = { url: url, title: title }

    Discourse.cache.write(cache_key(url), onebox, expires_in: 1.day) if !opts[:skip_cache]
    onebox
  end

  def self.cache_key(url)
    "inline_onebox:#{Oneboxer.onebox_locale}:#{url}"
  end

  def self.post_author_for_title(topic, post_number)
    guardian = Guardian.new
    post = topic.posts.find_by(post_number: post_number)
    author = post&.user
    if author && guardian.can_see_post?(post) && post.post_type == Post.types[:regular]
      author.username
    end
  end
end
