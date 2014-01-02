#
# Creates and Updates Topics based on an RSS or ATOM feed.
#
require 'digest/sha1'
require_dependency 'post_creator'
require_dependency 'post_revisor'
require 'open-uri'

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

      require 'simple-rss'
      rss = SimpleRSS.parse open(SiteSetting.feed_polling_url)

      rss.items.each do |i|
        url = i.link
        url = i.id if url.blank? || url !~ /^https?\:\/\//

        content = i.content || i.description
        if content
          TopicEmbed.import(user, url, i.title, CGI.unescapeHTML(content.scrub))
        end
      end
    end

  end
end
