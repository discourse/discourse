# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseRssPolling::FeedSettingFinder do
  before do
    DiscourseRssPolling::RssFeed.create!(url: "https://blog.discourse.org/feed/", author: "system")
    DiscourseRssPolling::RssFeed.create!(url: "https://www.withwww.com/feed", author: "system")
    DiscourseRssPolling::RssFeed.create!(url: "https://withoutwww.com/feed", author: "system")
  end

  describe ".by_embed_url" do
    it "finds the feed setting with the same host" do
      setting =
        DiscourseRssPolling::FeedSettingFinder.by_embed_url("https://blog.discourse.org/2018/03/")
      expect(setting.feed_url).to eq("https://blog.discourse.org/feed/")
    end

    it "neglects www in the url" do
      setting = DiscourseRssPolling::FeedSettingFinder.by_embed_url("https://withwww.com/a-post/")
      expect(setting.feed_url).to eq("https://www.withwww.com/feed")

      setting =
        DiscourseRssPolling::FeedSettingFinder.by_embed_url("https://www.withoutwww.com/a-post/")
      expect(setting.feed_url).to eq("https://withoutwww.com/feed")
    end
  end
end
