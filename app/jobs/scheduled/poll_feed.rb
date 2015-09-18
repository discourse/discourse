#
# Creates and Updates Topics based on an RSS or ATOM feed.
#
require 'digest/sha1'
require_dependency 'post_creator'
require_dependency 'post_revisor'
require 'open-uri'

module Jobs
  class PollFeed < Jobs::Scheduled
    every 1.hour

    sidekiq_options retry: false

    def execute(args)
      poll_feed if SiteSetting.feed_polling_enabled? &&
                   SiteSetting.feed_polling_url.present?
    end

    def feed_key
      @feed_key ||= "feed-modified:#{Digest::SHA1.hexdigest(SiteSetting.feed_polling_url)}"
    end

    def poll_feed
      feed = Feed.new
      import_topics(feed.topics)
    end

    private

    def import_topics(feed_topics)
      feed_topics.each do |topic|
        import_topic(topic)
      end
    end

    def import_topic(topic)
      if topic.user
        TopicEmbed.import(topic.user, topic.url, topic.title, CGI.unescapeHTML(topic.content.scrub))
      end
    end

    class Feed
      require 'simple-rss'

      if SiteSetting.embed_username_key_from_feed.present?
        SimpleRSS.item_tags << SiteSetting.embed_username_key_from_feed.to_sym
      end

      def initialize
        @feed_url = SiteSetting.feed_polling_url
        @feed_url = "http://#{@feed_url}" if @feed_url !~ /^https?\:\/\//
      end

      def topics
        feed_topics = []

        rss.items.each do |i|
          current_feed_topic = FeedTopic.new(i)
          feed_topics << current_feed_topic if current_feed_topic.content
        end

        return feed_topics
      end

      private

      def rss
        SimpleRSS.parse open(@feed_url, allow_redirections: :all)
      end

    end

    class FeedTopic
      def initialize(article_rss_item)
        @article_rss_item = article_rss_item
      end

      def url
        link = @article_rss_item.link
        if url?(link)
          return link
        else
          return @article_rss_item.id
        end
      end

      def content
        if @article_rss_item.content
          @article_rss_item.content.scrub
        else
          @article_rss_item.description.scrub
        end
      end

      def title
        @article_rss_item.title.scrub
      end

      def user
        author_user || default_user
      end

      private

      def url?(link)
        if link.blank? || link !~ /^https?\:\/\//
          return false
        else
          return true
        end
      end

      def author_username
        begin
          @article_rss_item.send(SiteSetting.embed_username_key_from_feed.to_sym)
        rescue
          nil
        end
      end

      def default_user
        find_user(SiteSetting.embed_by_username.downcase)
      end

      def author_user
        return nil if !author_username.present?

        find_user(author_username)
      end

      def find_user(user_name)
        User.where(username_lower: user_name).first
      end

    end

  end

end
