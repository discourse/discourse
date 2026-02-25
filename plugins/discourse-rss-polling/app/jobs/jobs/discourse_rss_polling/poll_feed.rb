# frozen_string_literal: true

require "rss"

module Jobs
  module DiscourseRssPolling
    class PollFeed < ::Jobs::Base
      def execute(args)
        return unless SiteSetting.rss_polling_enabled

        @author = User.find_by_username(args[:author_username])
        return if @author.nil?

        @discourse_category_id = args[:discourse_category_id]
        return if @discourse_category_id.present? && !Category.exists?(@discourse_category_id)

        @feed_url = args[:feed_url]
        @discourse_tags = args[:discourse_tags]
        @feed_category_filter = args[:feed_category_filter]

        poll_feed if not_polled_recently?
      end

      private

      attr_reader :feed_url, :author, :discourse_category_id, :discourse_tags, :feed_category_filter

      def feed_key
        "rss-polling-feed-polled:#{Digest::SHA1.hexdigest(feed_url)}"
      end

      def not_polled_recently?
        Discourse.redis.set(
          feed_key,
          1,
          ex: SiteSetting.rss_polling_frequency.minutes - 10.seconds,
          nx: true,
        )
      end

      def poll_feed
        topics_polled_from_feed.each do |feed_item|
          next if feed_item.content.blank?
          next if feed_item.title.blank?
          if feed_category_filter.present? &&
               feed_item.categories.none? { |c| c.include?(feed_category_filter) }
            next
          end

          cook_method = feed_item.is_youtube? ? Post.cook_methods[:regular] : nil

          updated_tags = discourse_tags
          if !SiteSetting.rss_polling_update_tags
            url = TopicEmbed.normalize_url(feed_item.url)
            updated_tags = nil if TopicEmbed.topic_embed_by_url(url).present?
          end

          post =
            TopicEmbed.import(
              author,
              feed_item.url,
              feed_item.title,
              CGI.unescapeHTML(feed_item.content),
              category_id: discourse_category_id,
              tags: updated_tags,
              cook_method: cook_method,
            )
          if post && (post.created_at == post.updated_at) # new post
            if SiteSetting.rss_polling_use_pubdate
              begin
                post_time = feed_item.pubdate
                post.created_at = post_time
                post.save!
                post.topic.created_at = post_time
                post.topic.bumped_at = post_time
                post.topic.last_posted_at = post_time
                post.topic.save!
              rescue StandardError
                Rails.logger.error("Invalid pubDate for topic #{post.topic.id} #{post_time}")
              end
            end

            set_image_as_thumbnail(post, feed_item.image_link) if feed_item.image_link
          end
        end
      end

      def set_image_as_thumbnail(post, image_link)
        tmp = nil
        image_uri = nil

        fd = FinalDestination.new(image_link)
        fd.get do |response, chunk, uri|
          throw :done if uri.blank? || !response.is_a?(Net::HTTPSuccess)

          if tmp.nil?
            image_uri = uri
            tmp = Tempfile.new("downloaded_image")
            tmp.binmode
          end

          tmp.write(chunk)
        end

        return if tmp.nil?

        tmp.rewind
        source_filename = File.basename(image_uri.path)
        upload = UploadCreator.new(tmp, source_filename).create_for(post.user.id)
        UploadReference.ensure_exist!(upload_ids: [upload.id], target: post)
        post.raw = "<img src=\"#{upload.url}\"><br/><br/>#{post.raw}"
        post.save!
        post.rebake!
      rescue => e
        Rails.logger.error(
          "RSS Polling: Unable to download and save #{image_link} for post ##{post.id} #{e.message}",
        )
      ensure
        tmp&.close
        tmp&.unlink
      end

      def topics_polled_from_feed
        raw_feed = fetch_raw_feed

        if raw_feed.blank?
          Rails.logger.warn("RSS Polling: Failed to fetch feed from #{feed_url}")
          return []
        end

        parsed_feed = RSS::Parser.parse(raw_feed, false)

        if parsed_feed.blank?
          Rails.logger.warn("RSS Polling: Unable to parse feed from #{feed_url}")
          return []
        end

        parsed_feed.items.map { |item| ::DiscourseRssPolling::FeedItem.new(item) }
      rescue RSS::NotWellFormedError, RSS::InvalidRSSError => e
        Discourse.warn_exception(e, message: "RSS Polling: Invalid RSS from #{feed_url}")
        []
      end

      def fetch_raw_feed
        url, headers = extract_api_credentials(@feed_url)
        body = +""

        fd = FinalDestination.new(url, headers:)
        response_status = nil

        fd.get do |response, chunk, uri|
          if uri.blank? || !response.is_a?(Net::HTTPSuccess)
            response_status = response&.code
            throw :done
          end
          body << chunk
        end

        if body.blank? && response_status.present?
          Rails.logger.warn(
            "RSS Polling: HTTP #{response_status} when fetching #{feed_url} (status: #{fd.status})",
          )
        end

        body.presence
      end

      def extract_api_credentials(url)
        uri = URI.parse(url)
        return url, {} if uri.query.blank?

        params = CGI.parse(uri.query)
        api_key = params.delete("api_key")&.first
        api_username = params.delete("api_username")&.first

        return url, {} if api_key.blank?

        headers = { "Api-Key" => api_key }
        headers["Api-Username"] = api_username if api_username.present?

        uri.query = params.empty? ? nil : URI.encode_www_form(params)
        [uri.to_s, headers]
      end
    end
  end
end
