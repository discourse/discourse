#
# Creates and Updates Topics based on an RSS or ATOM feed.
#
require 'digest/sha1'
require_dependency 'post_creator'
require_dependency 'post_revisor'

module Jobs
  class PollFeed < Jobs::Scheduled
    recurrence { hourly }
    sidekiq_options retry: false

    def execute(args)
      poll_feed if SiteSetting.feed_polling_enabled? &&
                   SiteSetting.feed_polling_url.present? &&
                   SiteSetting.embed_by_username.present?
    end

    def feed_key
      @feed_key ||= "feed-modified:#{Digest::SHA1.hexdigest(SiteSetting.feed_polling_url)}"
    end

    def poll_feed
      user = User.where(username_lower: SiteSetting.embed_by_username.downcase).first
      return if user.blank?

      fetch_opts = {}

      last_modified = $redis.get(feed_key)
      if last_modified.present?
        fetch_opts[:if_modified_since] = Time.parse(last_modified)
      end

      require 'feedzirra'
      feed = Feedzirra::Feed.fetch_and_parse(SiteSetting.feed_polling_url, fetch_opts)

      if feed.respond_to?(:entries)
        feed.entries.each do |e|
          url = e.url
          url = e.id if url.blank? || url !~ /^https?\:\/\//
          TopicEmbed.import(user, url, e.title, e.content)
        end

        # Store last modified for faster requests from feeds
        $redis.set(feed_key, feed.last_modified)

        false
      end
    end

  end
end
