#
# Creates and Updates Topics based on an RSS or ATOM feed.
#
require 'digest/sha1'
require 'open-uri'
require 'rss'
require_dependency 'feed_item_accessor'
require_dependency 'feed_element_installer'
require_dependency 'post_creator'
require_dependency 'post_revisor'

module Jobs
  class PollFeed < Jobs::Scheduled
    every 5.minutes

    sidekiq_options retry: false

    def execute(args)
      poll_feed if SiteSetting.feed_polling_enabled? &&
                   SiteSetting.feed_polling_url.present? &&
                   not_polled_recently?
    end

    def feed_key
      "feed-modified:#{Digest::SHA1.hexdigest(SiteSetting.feed_polling_url)}"
    end

    def poll_feed
      feed = Feed.new
      import_topics(feed.topics)
    end

    private

    def not_polled_recently?
      $redis.set(
        'feed-polled-recently',
        "1",
        ex: SiteSetting.feed_polling_frequency_mins.minutes - 10.seconds,
        nx: true
      )
    end

    def import_topics(feed_topics)
      feed_topics.each do |topic|
        import_topic(topic)
      end
    end

    def import_topic(topic)
      if topic.user
        TopicEmbed.import(topic.user, topic.url, topic.title, CGI.unescapeHTML(topic.content))
      end
    end

    class Feed
      def initialize
        @feed_url = SiteSetting.feed_polling_url
        @feed_url = "http://#{@feed_url}" if @feed_url !~ /^https?\:\/\//
      end

      def topics
        feed_topics = []

        rss = fetch_rss
        return feed_topics unless rss.present?

        rss.items.each do |i|
          current_feed_topic = FeedTopic.new(i)
          feed_topics << current_feed_topic if current_feed_topic.content
        end

        return feed_topics
      end

      private

      def fetch_rss
        if SiteSetting.embed_username_key_from_feed.present?
          FeedElementInstaller.install_rss_element(SiteSetting.embed_username_key_from_feed)
          FeedElementInstaller.install_atom_element(SiteSetting.embed_username_key_from_feed)
        end

        RSS::Parser.parse(open(@feed_url, allow_redirections: :all), false)
      rescue OpenURI::HTTPError, RSS::NotWellFormedError
        nil
      end
    end

    class FeedTopic
      def initialize(article_rss_item)
        @accessor = FeedItemAccessor.new(article_rss_item)
      end

      def url
        link = @accessor.link
        if url?(link)
          return link
        else
          return @accessor.element_content(:id)
        end
      end

      def content
        content = nil

        %i[content_encoded content description].each do |content_element_name|
          content ||= @accessor.element_content(content_element_name)
        end

        content&.force_encoding('UTF-8')&.scrub
      end

      def title
        @accessor.element_content(:title).force_encoding('UTF-8').scrub
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
        @accessor.element_content(SiteSetting.embed_username_key_from_feed.to_sym)
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
