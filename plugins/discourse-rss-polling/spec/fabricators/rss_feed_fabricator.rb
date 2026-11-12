# frozen_string_literal: true

Fabricator(:rss_feed, from: "DiscourseRssPolling::RssFeed") do
  url { sequence(:url) { |i| "https://blog.example.com/feed-#{i}" } }
  user
end
