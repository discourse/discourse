#
# Creates and Updates Topics based on an RSS or ATOM feed.
#
require 'digest/sha1'
require 'excon'
require_dependency 'final_destination'
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
      ensure_rss_loaded
      # defer loading rss
      feed = Feed.new
      import_topics(feed.topics)
    end

    private

    @@rss_loaded = false

    # rss lib is very expensive memory wise, no need to load it till it is needed
    def ensure_rss_loaded
      return if @@rss_loaded
      require 'rss'
      require_dependency 'feed_item_accessor'
      require_dependency 'feed_element_installer'
      @@rss_loaded = true
    end

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

        rss = parsed_feed
        return feed_topics unless rss.present?

        rss.items.each do |i|
          current_feed_topic = FeedTopic.new(i)
          feed_topics << current_feed_topic if current_feed_topic.content
        end

        return feed_topics
      end

      private

      def parsed_feed
        raw_feed = fetch_rss
        return nil if raw_feed.blank?

        if SiteSetting.embed_username_key_from_feed.present?
          FeedElementInstaller.install(SiteSetting.embed_username_key_from_feed, raw_feed)
        end

        RSS::Parser.parse(raw_feed)
      rescue RSS::NotWellFormedError, RSS::InvalidRSSError
        nil
      end

      def fetch_rss
        final_destination = FinalDestination.new(@feed_url, verbose: true)
        feed_final_url = final_destination.resolve
        return nil unless final_destination.status == :resolved

        Excon.new(feed_final_url.to_s).request(method: :get, expects: 200).body
      rescue Excon::Error::HTTPStatus
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
        @accessor.element_content(SiteSetting.embed_username_key_from_feed.sub(':', '_'))
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
