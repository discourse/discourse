# frozen_string_literal: true

module Jobs
  module DiscourseRssPolling
    class PollFeed < ::Jobs::Base
      def execute(args)
        return unless SiteSetting.rss_polling_enabled

        @feed_url = args[:feed_url]
        @author = resolve_author(args)
        @discourse_tags = args[:discourse_tags]
        @feed_category_filter = args[:feed_category_filter]
        @rss_feed_id = args[:rss_feed_id]
        @discourse_category_id = args[:discourse_category_id]

        return if feed_disabled?

        if @discourse_category_id.present? && !Category.exists?(@discourse_category_id)
          record_category_deleted(force: args[:force])
          return
        end

        if args[:force]
          mark_polled
        else
          return unless not_polled_recently?
        end

        poll_feed
      end

      private

      attr_reader :feed_url,
                  :author,
                  :discourse_category_id,
                  :discourse_tags,
                  :feed_category_filter,
                  :rss_feed_id

      def resolve_author(args)
        if args[:user_id]
          user = User.find_by(id: args[:user_id])
          return user if user

          Rails.logger.warn(
            "RSS Polling: user_id #{args[:user_id]} not found for feed #{redacted_feed_url}, falling back to system user",
          )
        elsif args[:author_username].present?
          user = User.find_by_username(args[:author_username])
          return user if user

          Rails.logger.warn(
            "RSS Polling: username '#{args[:author_username]}' not found for feed #{redacted_feed_url}, falling back to system user",
          )
        end

        Discourse.system_user
      end

      def feed_key
        "rss-polling-feed-polled:#{Digest::SHA1.hexdigest(feed_url)}"
      end

      def poll_window
        SiteSetting.rss_polling_frequency.minutes - 10.seconds
      end

      def not_polled_recently?
        Discourse.redis.set(feed_key, 1, ex: poll_window, nx: true)
      end

      def mark_polled
        Discourse.redis.set(feed_key, 1, ex: poll_window)
      end

      def feed_disabled?
        rss_feed_id.present? &&
          !::DiscourseRssPolling::RssFeed.where(id: rss_feed_id, enabled: true).exists?
      end

      def poll_feed
        outcomes = []

        fetch = ::DiscourseRssPolling::RssFeed::Action::FetchFeed.call(feed_url:)

        unless SiteSetting.rss_polling_update_tags
          already_imported =
            ::DiscourseRssPolling::RssFeed::Action::ImportedTopics.call(feed_items: fetch.items)
        end

        fetch.items.each do |feed_item|
          status, reason =
            ::DiscourseRssPolling::RssFeed::Action::AnalyzeItem.call(
              feed_item:,
              feed_category_filter:,
            )

          if status == ::DiscourseRssPolling::RssFeed::Action::AnalyzeItem::SKIPPED
            outcomes << feed_item.outcome(status: :skipped, reason:)
            log_verbose("Skipped '#{feed_item.title || feed_item.url}' (#{reason})")
            next
          end

          cook_method = feed_item.is_youtube? ? Post.cook_methods[:regular] : nil

          updated_tags = discourse_tags
          updated_tags = nil if already_imported&.key?(feed_item)

          post =
            begin
              TopicEmbed.import(
                author,
                feed_item.url,
                feed_item.title,
                CGI.unescapeHTML(feed_item.content),
                category_id: discourse_category_id,
                tags: updated_tags,
                cook_method: cook_method,
              )
            rescue => e
              outcomes << feed_item.outcome(status: :failed, reason: e.message.to_s.truncate(200))
              log_verbose("Failed to import '#{feed_item.title || feed_item.url}' (#{e.message})")
              next
            end

          if post.nil?
            outcomes << feed_item.outcome(status: :failed, reason: :import_rejected)
            log_verbose("Failed to import '#{feed_item.title || feed_item.url}'")
            next
          end

          new_post = post.created_at == post.updated_at
          item_status = new_post ? :imported : :updated
          outcomes << feed_item.outcome(status: item_status, topic_url: post.topic&.relative_url)

          log_verbose("Imported '#{feed_item.title}' (#{feed_item.url})")

          if new_post
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

        record_attempt(outcomes, error: fetch.error&.to_s)
      rescue => e
        Discourse.warn_exception(
          e,
          message: "RSS Polling: error while polling feed #{redacted_feed_url}",
        )
        record_attempt(outcomes, error: "unknown")
        raise
      end

      def record_category_deleted(force:)
        return if rss_feed_id.blank?

        unless force
          latest = ::DiscourseRssPolling::PollAttempt.where(rss_feed_id:).recent.first
          return if latest&.error == "category_deleted"
        end

        record_attempt([], error: "category_deleted")
      end

      def record_attempt(outcomes, error: nil)
        return if rss_feed_id.blank?

        ::DiscourseRssPolling::PollAttempt.record!(rss_feed_id:, items: outcomes, error:)
      rescue => e
        Rails.logger.warn(
          "RSS Polling: failed to record poll attempt for feed #{rss_feed_id}: #{e.message}",
        )
      end

      def redacted_feed_url
        @redacted_feed_url ||= ::DiscourseRssPolling::FeedUrl.redact(feed_url)
      end

      def log_verbose(message)
        return unless SiteSetting.rss_polling_verbose_logging

        Rails.logger.info("RSS Polling: #{redacted_feed_url}: #{message}")
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
    end
  end
end
