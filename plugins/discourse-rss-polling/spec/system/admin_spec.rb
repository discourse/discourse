# frozen_string_literal: true

RSpec.describe "Rss Polling - admin" do
  fab!(:current_user, :admin)
  fab!(:category_1, :category)
  fab!(:tag_1, :tag)

  let(:url) { "http://example.com/rss" }

  before do
    SiteSetting.rss_polling_enabled = true
    sign_in(current_user)
  end

  it "can save an rss polling configuration" do
    visit("/admin/plugins/discourse-rss-polling/feeds")

    find(".rss-polling-feeds__add").click

    form = PageObjects::Components::FormKit.new(".rss-polling-feed-form")
    form.field("feed_url").fill_in(url)
    form.field("feed_category_filter").fill_in("updates")

    author = PageObjects::Components::SelectKit.new(".rss-polling-feed-form__author")
    author.expand
    author.search(current_user.username)
    author.select_row_by_value(current_user.username)

    category = PageObjects::Components::SelectKit.new(".rss-polling-feed-form__category")
    category.expand
    category.search(category_1.name)
    category.select_row_by_value(category_1.id)

    tag = PageObjects::Components::SelectKit.new(".rss-polling-feed-form__tags")
    tag.expand
    tag.search(tag_1.name)
    tag.select_row_by_name(tag_1.name)
    tag.collapse

    form.submit

    expect(page).to have_css(".rss-polling-feed")

    expect(DiscourseRssPolling::RssFeed.last).to have_attributes(
      url:,
      user_id: current_user.id,
      category_filter: "updates",
      category_id: category_1.id,
      tags: tag_1.name,
    )
  end
end
