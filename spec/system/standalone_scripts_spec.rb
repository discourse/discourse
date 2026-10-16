# frozen_string_literal: true

describe "Standalone scripts" do
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic:) }

  describe "browser-detect.js / browser-update.js" do
    it "does not flag a supported browser as unsupported" do
      browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }

      expect(browser_root.locator("#main-outlet").filter(visible: true)).not_to have_count(0)
      expect(
        browser_root.locator("script[data-discourse-entrypoint='js/browser-detect']"),
      ).not_to have_count(0)
      expect(browser_root.locator("script[src*='browser-update']")).not_to have_count(0)

      expect(
        browser_page.evaluate(
          "function(arguments) { return !!window.unsupportedBrowser }",
          arg: [],
        ),
      ).to eq(false)
      expect(browser_root.locator(".buorg").filter(visible: true)).to have_count(0)
      expect(browser_root.locator("body.crawler").filter(visible: true)).to have_count(0)
    end
  end

  describe "onpopstate-handler.js" do
    it "registers a popstate handler on the 404 page" do
      browser_page
        .goto("/this-route-definitely-does-not-exist")
        .tap { SystemBrowserBootstrap.wait_for(browser_page) }

      expect(
        browser_root.locator("script[data-discourse-entrypoint='js/onpopstate-handler']"),
      ).not_to have_count(0)
      expect(
        browser_page.evaluate("function(arguments) { return typeof window.onpopstate }", arg: []),
      ).to eq("function")
    end
  end

  context "with Google analytics scripts" do
    before do
      browser_page.then do |pw_page|
        pw_page.route(
          /googletagmanager\.com|google-analytics\.com/,
          ->(route, _request) { route.fulfill(status: 204, body: "") },
        )
      end
    end

    describe "google-tag-manager.js" do
      before { SiteSetting.gtm_container_id = "GTM-ABCDEF" }

      it "initializes the dataLayer when a container id is configured" do
        browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }

        expect(
          browser_page.evaluate(
            "function(arguments) { return Array.isArray(window.dataLayer) }",
            arg: [],
          ),
        ).to eq(true)
        expect(
          browser_page.evaluate(
            "function(arguments) { return window.dataLayer.some((entry) => entry && entry['gtm.start']) }",
            arg: [],
          ),
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
        browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }

        expect(
          browser_page.evaluate("function(arguments) { return typeof window.ga }", arg: []),
        ).to eq("function")
      end
    end

    describe "google-universal-analytics-v4.js" do
      before do
        Rails.env.stubs(:production?).returns(true)
        SiteSetting.ga_version = "v4_gtag"
        SiteSetting.ga_universal_tracking_code = "G-ABCDEF"
      end

      it "defines the gtag function" do
        browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }

        expect(
          browser_page.evaluate("function(arguments) { return typeof window.gtag }", arg: []),
        ).to eq("function")
      end
    end
  end

  describe "print-page.js" do
    it "triggers the browser print dialog on the topic print page" do
      browser_page.then do |pw_page|
        pw_page.add_init_script(script: "window.print = () => { window.__printCalled = true; };")
      end

      browser_page
        .goto("/t/#{topic.slug}/#{topic.id}/print")
        .tap { SystemBrowserBootstrap.wait_for(browser_page) }

      try_until_success do
        expect(
          browser_page.evaluate("function(arguments) { return !!window.__printCalled }", arg: []),
        ).to eq(true)
      end
    end
  end

  describe "pageview.js" do
    it "sends a beacon pageview tracking request on a non-ember page" do
      pageview_requests = []
      browser_page.then do |pw_page|
        pw_page.on(
          "request",
          ->(request) { pageview_requests << request.url if request.url.end_with?("/srv/pv") },
        )
      end

      browser_page.goto("/safe-mode").tap { SystemBrowserBootstrap.wait_for(browser_page) }

      try_until_success { expect(pageview_requests).not_to RSpecPredicates.be_empty }
    end

    it "does not send tracking requests when request tracking is disabled in development" do
      original_track_requests = ENV.delete("TRACK_REQUESTS")
      Rails.env.stubs(:development?).returns(true)
      tracking_requests = []
      browser_page.then do |pw_page|
        pw_page.on(
          "request",
          lambda { |request| tracking_requests << request.url if request.url.end_with?("/srv/pv") },
        )
      end

      browser_page.goto("/safe-mode").tap { SystemBrowserBootstrap.wait_for(browser_page) }

      browser_page.then { |pw_page| pw_page.wait_for_timeout(100) }
      expect(tracking_requests).to eq([])
    ensure
      ENV["TRACK_REQUESTS"] = original_track_requests if original_track_requests
    end
  end

  describe "publish.js" do
    fab!(:published_page) { Fabricate(:published_page, topic:, public: true) }

    before { SiteSetting.enable_page_publishing = true }

    it "renders a published page without script errors" do
      page_errors = []
      browser_page.then do |pw_page|
        pw_page.on("pageerror", ->(error) { page_errors << error.message })
      end

      browser_page
        .goto("/pub/#{published_page.slug}")
        .tap { SystemBrowserBootstrap.wait_for(browser_page) }

      expect(
        browser_root.locator(".published-page-content-body").filter(visible: true),
      ).not_to have_count(0)
      expect(
        browser_root.locator("script[data-discourse-entrypoint='js/publish']"),
      ).not_to have_count(0)
      expect(page_errors).to eq([])
    end
  end

  describe "embed-application.js" do
    before { SiteSetting.embed_any_origin = true }

    it "posts a resize message to the parent frame" do
      browser_page.then do |pw_page|
        pw_page.add_init_script(
          script:
            "window.addEventListener('message', (event) => { window.__embedMessage = event.data; });",
        )
      end

      browser_page
        .goto("/embed/comments?topic_id=#{topic.id}")
        .tap { SystemBrowserBootstrap.wait_for(browser_page) }

      expect(
        browser_root.locator("script[data-discourse-entrypoint='js/embed-application']"),
      ).not_to have_count(0)
      try_until_success do
        expect(
          browser_page.evaluate(
            "function(arguments) { return window.__embedMessage?.type }",
            arg: [],
          ),
        ).to eq("discourse-resize")
      end
    end
  end
end
