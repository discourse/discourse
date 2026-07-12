# frozen_string_literal: true

module DiscourseRssPolling
  class FeedSettingsController < SuperAdmin::SuperAdminController
    requires_plugin "discourse-rss-polling"

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

    def feed
      rss_feed = RssFeed.includes(:user).find_by(id: params[:id]) || raise(Discourse::NotFound)
      render json: FeedSettingSerializer.new(rss_feed, include_url: true, root: false)
    end

    def update
      RssFeed::Update.call(params: params[:feed_setting], guardian:) do
        on_success { |rss_feed:| render json: { success: true, id: rss_feed.id } }
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
        on_model_not_found(:rss_feed) { raise Discourse::NotFound }
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
      RssFeed::Test.call(**service_params) do
        on_success do |preview:, fetched:|
          render json: { items: preview || [], total: fetched.items.size }
        end
        on_failed_contract { render json: { error: :blank_feed_url }, status: :bad_request }
        on_failed_step(:fetch) do |step|
          render json: { error: step.error }, status: :unprocessable_entity
        end
        on_exceptions do |exception|
          Discourse.warn_exception(exception, message: "RSS Polling: failed to test feed")
          render json: { error: :unknown }, status: :unprocessable_entity
        end
      end
    end

    def history
      rss_feed = RssFeed.find_by(id: params[:id]) || raise(Discourse::NotFound)

      last_message_id = MessageBus.last_id(PollAttempt.message_bus_channel(rss_feed.id))
      attempts = rss_feed.poll_attempts.recent.limit(PollAttempt::KEEP_PER_FEED)

      render json: {
               id: rss_feed.id,
               feed_url: rss_feed.url,
               poll_attempts: serialize_data(attempts, PollAttemptSerializer),
               last_message_id:,
             }
    end

    def poll
      RssFeed::Poll.call(**service_params) do
        on_success { head :no_content }
        on_failed_contract { raise Discourse::NotFound }
        on_model_not_found(:rss_feed) { raise Discourse::NotFound }
      end
    end

    def set_enabled
      RssFeed::SetEnabled.call(**service_params) do
        on_success { head :no_content }
        on_failed_contract { raise Discourse::InvalidParameters.new(:enabled) }
        on_model_not_found(:rss_feed) { raise Discourse::NotFound }
      end
    end

    def category_requirements
      category = Category.find_by(id: params[:category_id])
      render json: { required_tag_groups: RequiredTagGroups.for_category(category) }
    end

    def destroy
      RssFeed::Destroy.call(**service_params) do
        on_success { head :no_content }
        on_failed_contract { raise Discourse::NotFound }
        on_model_not_found(:rss_feed) { raise Discourse::NotFound }
      end
    end
  end
end
