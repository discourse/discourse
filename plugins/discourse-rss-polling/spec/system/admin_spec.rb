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

  it "tests a feed and saves the configuration" do
    stub_request(:get, url).to_return(status: 200, body: file_from_fixtures("feed.rss", "feed"))

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

    find(".rss-polling-feed-form__test").click

    expect(page).to have_css(".rss-polling-feed-test")

    form.submit

    expect(page).to have_css(".rss-polling-feed-form")

    expect(DiscourseRssPolling::RssFeed.last).to have_attributes(
      url:,
      user_id: current_user.id,
      category_filter: "updates",
      category_id: category_1.id,
      tags: tag_1.name,
    )
  end

  it "keeps Test feed enabled and surfaces the server error for a blank URL" do
    visit("/admin/plugins/discourse-rss-polling/feeds")

    find(".rss-polling-feeds__add").click

    expect(page).to have_no_css(".rss-polling-feed-form__test[disabled]")

    find(".rss-polling-feed-form__test").click

    expect(page).to have_css(".rss-polling-feed-test__error")
    expect(page).to have_content(I18n.t("js.admin.rss_polling.test.errors.blank_feed_url"))
  end

  it "can disable and re-enable a feed without deleting it" do
    feed = Fabricate(:rss_feed, user: current_user)

    visit("/admin/plugins/discourse-rss-polling/feeds")

    expect(page).to have_css(".rss-polling-feed")

    toggle = PageObjects::Components::DToggleSwitch.new(".rss-polling-feed__toggle")
    expect(toggle).to be_checked

    toggle.toggle

    expect(page).to have_css(".rss-polling-feed.is-disabled")
    expect(toggle).to be_unchecked
    try_until_success { expect(feed.reload.enabled).to eq(false) }

    toggle.toggle

    expect(page).to have_no_css(".rss-polling-feed.is-disabled")
    expect(toggle).to be_checked
    try_until_success { expect(feed.reload.enabled).to eq(true) }
  end

  it "shows the feed settings and its poll history on one page" do
    feed = Fabricate(:rss_feed, user: current_user)
    DiscourseRssPolling::PollAttempt.record!(
      rss_feed_id: feed.id,
      items: [
        {
          "title" => "An imported item",
          "url" => "https://example.com/rss/item",
          "status" => "imported",
          "topic_url" => "/t/-/1",
        },
      ],
    )

    visit("/admin/plugins/discourse-rss-polling/feeds/#{feed.id}/edit")

    expect(page).to have_css(".rss-polling-feed-form")
    expect(page).to have_css(".rss-polling-feed-form__poll")
    expect(page).to have_css(".rss-polling-feed-history")
    expect(page).to have_content("1 imported")
  end

  it "disables Poll now while the feed has unsaved edits" do
    feed = Fabricate(:rss_feed, user: current_user, category_filter: "old")

    visit("/admin/plugins/discourse-rss-polling/feeds/#{feed.id}/edit")

    expect(page).to have_css(".rss-polling-feed-form__poll")
    expect(page).to have_no_css(".rss-polling-feed-form__poll[disabled]")

    form = PageObjects::Components::FormKit.new(".rss-polling-feed-form")
    form.field("feed_category_filter").fill_in("changed")

    expect(page).to have_css(".rss-polling-feed-form__poll[disabled]")

    form.submit

    expect(page).to have_no_css(".rss-polling-feed-form__poll[disabled]")
    expect(feed.reload.category_filter).to eq("changed")
  end

  it "disables Poll now while the feed is disabled" do
    feed = Fabricate(:rss_feed, user: current_user, enabled: false)

    visit("/admin/plugins/discourse-rss-polling/feeds/#{feed.id}/edit")

    expect(page).to have_css(".rss-polling-feed-form__poll[disabled]")

    PageObjects::Components::DToggleSwitch.new(".rss-polling-feed-form__toggle").toggle

    expect(page).to have_no_css(".rss-polling-feed-form__poll[disabled]")
    try_until_success { expect(feed.reload.enabled).to eq(true) }
  end

  it "redirects to the feeds list when editing a feed that no longer exists" do
    visit("/admin/plugins/discourse-rss-polling/feeds/0/edit")

    expect(page).to have_current_path("/admin/plugins/discourse-rss-polling/feeds")
    expect(page).to have_css(".rss-polling-feeds__add")
  end
end
