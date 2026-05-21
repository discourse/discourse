# frozen_string_literal: true

module DiscourseRssPolling
  class FeedSettingsController < Admin::AdminController
    requires_plugin "discourse-rss-polling"

    def show
      feeds = RssFeed.includes(:user)
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
