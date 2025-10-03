# frozen_string_literal: true

module DiscourseRssPolling
  class FeedSettingsController < Admin::AdminController
    requires_plugin "discourse-rss-polling"

    def show
      render json: FeedSettingFinder.all
    end

    def update
      feed = params[:feed_setting]

      if feed
        rss_feed = RssFeed.find_by_id(feed["id"]) || RssFeed.new

        rss_feed.assign_attributes(
          url: feed["feed_url"],
          author: feed["author_username"],
          category_id: feed["discourse_category_id"],
          tags: feed["discourse_tags"]&.join(","),
          category_filter: feed["feed_category_filter"],
        )
        if rss_feed.save
          render json: { success: true }
        else
          render json: {
                   success: false,
                   errors: rss_feed.errors.full_messages,
                 },
                 status: :unprocessable_entity
        end
      else
        render json: { success: false, error: "Invalid feed data" }, status: :bad_request
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

    private

    def feed_setting_params
      params.require(:feed_settings)
    end
  end
end
