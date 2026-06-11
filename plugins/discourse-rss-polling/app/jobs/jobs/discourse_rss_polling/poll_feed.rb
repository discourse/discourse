# frozen_string_literal: true

module Jobs
  module DiscourseRssPolling
    class PollFeed < ::Jobs::Base
      def execute(args)
        return unless SiteSetting.rss_polling_enabled

        @author = resolve_author(args)

        @discourse_category_id = args[:discourse_category_id]
        return if @discourse_category_id.present? && !Category.exists?(@discourse_category_id)

        @feed_url = args[:feed_url]
        @discourse_tags = args[:discourse_tags]
        @feed_category_filter = args[:feed_category_filter]

        poll_feed if not_polled_recently?
      end

      private

      attr_reader :feed_url, :author, :discourse_category_id, :discourse_tags, :feed_category_filter

      def resolve_author(args)
        if args[:user_id]
          user = User.find_by(id: args[:user_id])
          return user if user

          Rails.logger.warn(
            "RSS Polling: user_id #{args[:user_id]} not found for feed #{args[:feed_url]}, falling back to system user",
          )
        elsif args[:author_username].present?
          user = User.find_by_username(args[:author_username])
          return user if user

          Rails.logger.warn(
            "RSS Polling: username '#{args[:author_username]}' not found for feed #{args[:feed_url]}, falling back to system user",
          )
        end

        Discourse.system_user
      end

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
        analyzer = ::DiscourseRssPolling::FeedAnalyzer.new(feed_category_filter:)

        topics_polled_from_feed.each do |feed_item|
          status, reason = analyzer.evaluate(feed_item)

          if status == ::DiscourseRssPolling::FeedAnalyzer::SKIPPED
            log_verbose("Skipped '#{feed_item.title || feed_item.url}' (#{reason})")
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

          log_verbose("Imported '#{feed_item.title}' (#{feed_item.url})")

          if post && (post.created_at == post.updated_at) # new post
            if SiteSetting.rss_polling_use_pubdate && (post_time = feed_item.pubdate)
              begin
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

      def log_verbose(message)
        return unless SiteSetting.rss_polling_verbose_logging

        Rails.logger.info("RSS Polling: #{feed_url}: #{message}")
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
        ::DiscourseRssPolling::FeedFetcher.new(feed_url).fetch.items
      end
    end
  end
end
