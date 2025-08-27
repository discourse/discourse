# frozen_string_literal: true

RSpec.describe "Rss Polling - admin", type: :system do
  fab!(:current_user) { Fabricate(:admin) }
  fab!(:category_1) { Fabricate(:category) }
  fab!(:tag_1) { Fabricate(:tag) }

  let(:url) { "http://example.com/rss" }

  before do
    SiteSetting.rss_polling_enabled = true
    sign_in(current_user)
  end

  it "can save an rss polling configuration" do
    visit("/admin/plugins/rss_polling")

    find(".add-rss-polling-feed").click
    find(".rss-polling-feed-url").fill_in(with: url)
    find(".rss-polling-feed-updates").fill_in(with: "updates")
    user = PageObjects::Components::SelectKit.new(".rss-polling-feed-user")
    user.search(current_user.username)
    user.select_row_by_value(current_user.username)
    category = PageObjects::Components::SelectKit.new(".rss-polling-feed-category")
    category.search(category_1.name)
    category.select_row_by_value(category_1.id)
    tag = PageObjects::Components::SelectKit.new(".rss-polling-feed-tag")
    tag.search(tag_1.name)
    tag.select_row_by_value(tag_1.name)
    find(".save-rss-polling-feed").click

    try_until_success do
      expect(DiscourseRssPolling::RssFeed.last).to have_attributes(
        url:,
        author: current_user.username,
        category_filter: "updates",
        category_id: category_1.id,
        tags: tag_1.name,
      )
    end
  end
end
