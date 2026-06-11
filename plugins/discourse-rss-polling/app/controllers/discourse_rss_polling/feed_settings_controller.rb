# frozen_string_literal: true

module DiscourseRssPolling
  class FeedSettingsController < Admin::AdminController
    requires_plugin "discourse-rss-polling"

    TEST_PREVIEW_LIMIT = 20

    def show
      feeds = RssFeed.includes(:user).order(:url)
      render json:
               ActiveModel::ArraySerializer.new(
                 feeds,
                 each_serializer: FeedSettingSerializer,
                 root: :feed_settings,
               ).to_json
    end

    alias_method :index, :show

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

    def test
      feed_url = params[:feed_url]
      raise Discourse::InvalidParameters.new(:feed_url) if feed_url.blank?

      result = FeedFetcher.new(feed_url).fetch

      if result.error
        render json: { error: result.error }, status: :unprocessable_entity
        return
      end

      analyzer = FeedAnalyzer.new(feed_category_filter: params[:feed_category_filter])
      preview_items = result.items.first(TEST_PREVIEW_LIMIT)
      item_keys = preview_items.index_with { |feed_item| embed_key(feed_item.url) }
      imported_keys = already_imported_keys(item_keys.values)

      items =
        preview_items.map do |feed_item|
          status, reason = analyzer.evaluate(feed_item)
          key = item_keys[feed_item]

          if status == FeedAnalyzer::WOULD_IMPORT && key && imported_keys.include?(key)
            status = :already_imported
          end

          feed_item.outcome(status:, reason:)
        end

      render json: { items:, total: result.items.size }
    rescue Discourse::InvalidParameters
      raise
    rescue => e
      Discourse.warn_exception(e, message: "RSS Polling: failed to test feed #{feed_url}")
      render json: { error: :unknown }, status: :unprocessable_entity
    end

    def history
      rss_feed = RssFeed.find_by(id: params[:id])
      raise Discourse::NotFound if rss_feed.nil?

      attempts = rss_feed.poll_attempts.recent.limit(PollAttempt::KEEP_PER_FEED)

      render json: {
               feed_url: rss_feed.url,
               poll_attempts: serialize_data(attempts, PollAttemptSerializer),
             }
    end

    def category_requirements
      category = Category.find_by(id: params[:category_id])
      render json: { required_tag_groups: RequiredTagGroups.for_category(category) }
    end

    def already_imported_keys(keys)
      keys = keys.compact.uniq
      return Set.new if keys.empty?

      patterns = keys.map { |key| "^https?://#{Regexp.escape(key)}$" }
      TopicEmbed
        .where("embed_url ~* ANY(ARRAY[?])", patterns)
        .pluck(:embed_url)
        .map { |embed_url| embed_key(embed_url) }
        .to_set
    end
    private :already_imported_keys

    def embed_key(url)
      return if url.blank?

      TopicEmbed.normalize_url(url).sub(%r{\Ahttps?\://}, "")
    end
    private :embed_key

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
