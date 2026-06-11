# frozen_string_literal: true

module DiscourseRssPolling
  class FeedSettingsController < Admin::AdminController
    requires_plugin "discourse-rss-polling"

    # Number of items shown in the "test feed" preview.
    TEST_PREVIEW_LIMIT = 20

    # Serves the admin SPA for the plugin show page's deep-link routes
    # (/feeds, /feeds/new, /feeds/:id/edit). `check_xhr` renders the Ember app
    # for full-page (HTML) requests; the feed data is fetched separately.
    def index
      show
    end

    def show
      feeds = RssFeed.includes(:user).order(:url)
      render json:
               ActiveModel::ArraySerializer.new(
                 feeds,
                 each_serializer: FeedSettingSerializer,
                 root: :feed_settings,
               ).to_json
    end

    def update
      FeedSetting::Update.call(params: params[:feed_setting]) do
        on_success { render json: { success: true } }
        on_failed_contract do |contract|
          render json: {
                   success: false,
                   errors: contract.errors.full_messages,
                 },
                 status: :bad_request
        end
        on_model_not_found(:user) do |_, params:|
          render json: {
                   success: false,
                   errors: [
                     I18n.t(
                       "rss_polling.errors.unknown_author_username",
                       username: params.author_username,
                     ),
                   ],
                 },
                 status: :unprocessable_entity
        end
        on_model_errors(:rss_feed) do |rss_feed|
          render json: {
                   success: false,
                   errors: rss_feed.errors.full_messages,
                 },
                 status: :unprocessable_entity
        end
        on_failure { render json: { success: false }, status: :unprocessable_entity }
      end
    end

    # Dry-run: fetch the feed and report which items would be imported or
    # skipped (and why), without creating any topics.
    def test
      feed_url = params[:feed_url]
      raise Discourse::InvalidParameters.new(:feed_url) if feed_url.blank?

      result = FeedFetcher.new(feed_url).fetch

      if result.error
        render json: { error: result.error }, status: :unprocessable_entity
        return
      end

      analyzer = FeedAnalyzer.new(feed_category_filter: params[:feed_category_filter])

      items =
        result
          .items
          .first(TEST_PREVIEW_LIMIT)
          .map do |feed_item|
            status, reason = analyzer.evaluate(feed_item)
            {
              title: feed_item.title,
              url: feed_item.url,
              status:,
              reason:,
              categories: feed_item.categories,
              published_at: feed_item.pubdate&.iso8601,
            }
          end

      render json: { items:, total: result.items.size }
    rescue Discourse::InvalidParameters
      raise
    rescue => e
      # The feed is fetched live and parsed leniently, so guard against
      # unexpected failures (malformed items, parser quirks) with a clean error.
      Discourse.warn_exception(e, message: "RSS Polling: failed to test feed #{feed_url}")
      render json: { error: :unknown }, status: :unprocessable_entity
    end

    def destroy
      feed = params[:feed_setting]
      rss_feed = RssFeed.find_by_id(feed["id"])

      if rss_feed
        rss_feed.destroy!
        render json: { success: true }
      else
        render json: { success: false, error: "Feed not found" }, status: :not_found
      end
    end
  end
end
