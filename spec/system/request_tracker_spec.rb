# frozen_string_literal: true

describe "request tracking", type: :system do
  before do
    ApplicationRequest.enable
    CachedCounting.reset
    CachedCounting.enable
  end

  after do
    CachedCounting.reset
    ApplicationRequest.disable
    CachedCounting.disable
  end

  it "tracks an anonymous visit correctly" do
    visit "/"

    try_until_success do
      CachedCounting.flush
      expect(ApplicationRequest.stats).to include(
        "page_view_anon_total" => 1,
        "page_view_anon_browser_total" => 1,
        "page_view_logged_in_total" => 0,
        "page_view_crawler_total" => 0,
      )
    end

    find(".nav-item_categories a").click

    try_until_success do
      CachedCounting.flush
      expect(ApplicationRequest.stats).to include(
        "page_view_anon_total" => 2,
        "page_view_anon_browser_total" => 2,
        "page_view_logged_in_total" => 0,
        "page_view_crawler_total" => 0,
      )
    end
  end

  it "tracks a crawler visit correctly" do
    # Can't change Selenium's user agent... so change site settings to make Discourse detect chrome as a crawler
    SiteSetting.crawler_user_agents += "|chrome"

    visit "/"

    try_until_success do
      CachedCounting.flush
      expect(ApplicationRequest.stats).to include(
        "page_view_anon_total" => 0,
        "page_view_anon_browser_total" => 0,
        "page_view_logged_in_total" => 0,
        "page_view_crawler_total" => 1,
      )
    end
  end

  it "tracks a logged-in session correctly" do
    sign_in Fabricate(:user)

    visit "/"

    try_until_success do
      CachedCounting.flush
      expect(ApplicationRequest.stats).to include(
        "page_view_anon_total" => 0,
        "page_view_anon_browser_total" => 0,
        "page_view_logged_in_total" => 1,
        "page_view_crawler_total" => 0,
        "page_view_logged_in_browser_total" => 1,
      )
    end

    find(".nav-item_categories a").click

    try_until_success do
      CachedCounting.flush
      expect(ApplicationRequest.stats).to include(
        "page_view_anon_total" => 0,
        "page_view_anon_browser_total" => 0,
        "page_view_logged_in_total" => 2,
        "page_view_crawler_total" => 0,
        "page_view_logged_in_browser_total" => 2,
      )
    end
  end

  it "tracks normal error pages correctly" do
    SiteSetting.bootstrap_error_pages = false

    visit "/foobar"

    try_until_success do
      CachedCounting.flush

      # Does not count error as a pageview
      expect(ApplicationRequest.stats).to include(
        "http_4xx_total" => 1,
        "page_view_anon_total" => 0,
        "page_view_anon_browser_total" => 0,
        "page_view_logged_in_total" => 0,
        "page_view_crawler_total" => 0,
      )
    end

    find("#site-logo").click

    try_until_success do
      CachedCounting.flush
      expect(ApplicationRequest.stats).to include(
        "http_4xx_total" => 1,
        "page_view_anon_total" => 1,
        "page_view_anon_browser_total" => 1,
        "page_view_logged_in_total" => 0,
        "page_view_crawler_total" => 0,
      )
    end
  end

  it "tracks non-ember pages correctly" do
    visit "/safe-mode"

    try_until_success do
      CachedCounting.flush

      # Does not count error as a pageview
      expect(ApplicationRequest.stats).to include(
        "page_view_anon_total" => 1,
        "page_view_anon_browser_total" => 1,
        "page_view_logged_in_total" => 0,
        "page_view_crawler_total" => 0,
      )
    end
  end

  it "tracks bootstrapped error pages correctly" do
    SiteSetting.bootstrap_error_pages = true

    visit "/foobar"

    try_until_success do
      CachedCounting.flush

      # Does not count error as a pageview
      expect(ApplicationRequest.stats).to include(
        "http_4xx_total" => 1,
        "page_view_anon_total" => 0,
        "page_view_anon_browser_total" => 0,
        "page_view_logged_in_total" => 0,
        "page_view_crawler_total" => 0,
      )
    end

    find("#site-logo").click

    try_until_success do
      CachedCounting.flush
      expect(ApplicationRequest.stats).to include(
        "http_4xx_total" => 1,
        "page_view_anon_total" => 1,
        "page_view_anon_browser_total" => 1,
        "page_view_logged_in_total" => 0,
        "page_view_crawler_total" => 0,
      )
    end
  end

  it "tracks published pages correctly" do
    SiteSetting.enable_page_publishing = true
    page =
      Fabricate(:published_page, public: true, slug: "some-page", topic: Fabricate(:post).topic)

    visit "/pub/some-page"

    try_until_success do
      CachedCounting.flush

      # Does not count error as a pageview
      expect(ApplicationRequest.stats).to include(
        "page_view_anon_total" => 1,
        "page_view_anon_browser_total" => 1,
        "page_view_logged_in_total" => 0,
        "page_view_crawler_total" => 0,
      )
    end
  end
end
