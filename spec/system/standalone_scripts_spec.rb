# frozen_string_literal: true

describe "Standalone scripts" do
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic:) }

  describe "browser-detect.js / browser-update.js" do
    it "does not flag a supported browser as unsupported" do
      visit("/")

      expect(page).to have_css("#main-outlet")
      expect(page).to have_css(
        "script[data-discourse-entrypoint='js/browser-detect']",
        visible: :all,
      )
      expect(page).to have_css("script[src*='browser-update']", visible: :all)

      expect(page.evaluate_script("!!window.unsupportedBrowser")).to eq(false)
      expect(page).to have_no_css(".buorg")
      expect(page).to have_no_css("body.crawler")
    end
  end

  describe "onpopstate-handler.js" do
    it "registers a popstate handler on the 404 page" do
      visit("/this-route-definitely-does-not-exist")

      expect(page).to have_css(
        "script[data-discourse-entrypoint='js/onpopstate-handler']",
        visible: :all,
      )
      expect(page.evaluate_script("typeof window.onpopstate")).to eq("function")
    end
  end

  context "with Google analytics scripts" do
    before do
      page.driver.with_playwright_page do |pw_page|
        pw_page.route(
          /googletagmanager\.com|google-analytics\.com/,
          ->(route, _request) { route.fulfill(status: 204, body: "") },
        )
      end
    end

    describe "google-tag-manager.js" do
      before { SiteSetting.gtm_container_id = "GTM-ABCDEF" }

      it "initializes the dataLayer when a container id is configured" do
        visit("/")

        expect(page.evaluate_script("Array.isArray(window.dataLayer)")).to eq(true)
        expect(
          page.evaluate_script("window.dataLayer.some((entry) => entry && entry['gtm.start'])"),
        ).to eq(true)
      end
    end

    describe "google-universal-analytics-v3.js" do
      before do
        Rails.env.stubs(:production?).returns(true)
        SiteSetting.ga_version = "v3_analytics"
        SiteSetting.ga_universal_tracking_code = "UA-123456-1"
      end

      it "defines the ga function" do
        visit("/")

        expect(page.evaluate_script("typeof window.ga")).to eq("function")
      end
    end

    describe "google-universal-analytics-v4.js" do
      before do
        Rails.env.stubs(:production?).returns(true)
        SiteSetting.ga_version = "v4_gtag"
        SiteSetting.ga_universal_tracking_code = "G-ABCDEF"
      end

      it "defines the gtag function" do
        visit("/")

        expect(page.evaluate_script("typeof window.gtag")).to eq("function")
      end
    end
  end

  describe "print-page.js" do
    it "triggers the browser print dialog on the topic print page" do
      page.driver.with_playwright_page do |pw_page|
        pw_page.add_init_script(script: "window.print = () => { window.__printCalled = true; };")
      end

      visit("/t/#{topic.slug}/#{topic.id}/print")

      try_until_success { expect(page.evaluate_script("!!window.__printCalled")).to eq(true) }
    end
  end

  describe "pageview.js" do
    it "sends a pageview tracking request on a non-ember page" do
      pageview_requests = []
      page.driver.with_playwright_page do |pw_page|
        pw_page.on(
          "request",
          ->(request) { pageview_requests << request.url if request.url.include?("/pageview") },
        )
      end

      visit("/safe-mode")

      try_until_success { expect(pageview_requests).not_to be_empty }
    end
  end

  describe "publish.js" do
    fab!(:published_page) { Fabricate(:published_page, topic:, public: true) }

    before { SiteSetting.enable_page_publishing = true }

    it "renders a published page without script errors" do
      page_errors = []
      page.driver.with_playwright_page do |pw_page|
        pw_page.on("pageerror", ->(error) { page_errors << error.message })
      end

      visit("/pub/#{published_page.slug}")

      expect(page).to have_css(".published-page-content-body")
      expect(page).to have_css("script[data-discourse-entrypoint='js/publish']", visible: :all)
      expect(page_errors).to eq([])
    end
  end

  describe "embed-application.js" do
    before { SiteSetting.embed_any_origin = true }

    it "posts a resize message to the parent frame" do
      page.driver.with_playwright_page do |pw_page|
        pw_page.add_init_script(
          script:
            "window.addEventListener('message', (event) => { window.__embedMessage = event.data; });",
        )
      end

      visit("/embed/comments?topic_id=#{topic.id}")

      expect(page).to have_css(
        "script[data-discourse-entrypoint='js/embed-application']",
        visible: :all,
      )
      try_until_success do
        expect(page.evaluate_script("window.__embedMessage?.type")).to eq("discourse-resize")
      end
    end
  end
end
