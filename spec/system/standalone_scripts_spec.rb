# frozen_string_literal: true

describe "Standalone scripts" do
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic:) }

  it "serves the health check without loading Ember" do
    visit "/srv/status"

    expect(page.status_code).to eq(200)
    expect(page).to have_text("ok", exact: true)
    expect(page).to have_no_css("discourse-assets", visible: :all)
  end

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
    it "sends a beacon pageview tracking request on a non-ember page" do
      pageview_requests = []
      page.driver.with_playwright_page do |pw_page|
        pw_page.on(
          "request",
          ->(request) { pageview_requests << request.url if request.url.end_with?("/srv/pv") },
        )
      end

      visit("/safe-mode")

      try_until_success { expect(pageview_requests).not_to be_empty }
    end

    it "does not send tracking requests when request tracking is disabled in development" do
      original_track_requests = ENV.delete("TRACK_REQUESTS")
      Rails.env.stubs(:development?).returns(true)
      tracking_requests = []
      page.driver.with_playwright_page do |pw_page|
        pw_page.on(
          "request",
          lambda { |request| tracking_requests << request.url if request.url.end_with?("/srv/pv") },
        )
      end

      visit("/safe-mode")

      page.driver.with_playwright_page { |pw_page| pw_page.wait_for_timeout(100) }
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

# Coverage for the disposable, persistent Chromium profile used by the CI
# system-test driver (`spec/support/system/browser_profile.rb`) and for the
# soft reset that replaces the test document between examples
# (`spec/support/system/capybara_patches.rb`).
#
# The isolation contract is that every example starts from a browser without
# page history, web storage, cookies, IndexedDB, granted permissions, or windows
# opened by a previous example. A soft reset must provide that while keeping the
# on-disk profile (that is the speedup); anything that observes profile state
# outside the document, such as a fake clock or a download, must force a hard
# reset that discards the profile instead.
RSpec.describe "System test browser profile isolation" do
  fab!(:user)

  def browser
    page.driver.send(:browser)
  end

  def profile_dir
    page
      .driver
      .send(:playwright_browser)
      .instance_variable_get(:@profiles)
      .fetch(playwright_context)
  end

  def playwright_context
    page.driver.with_playwright_page { |pw_page| pw_page.context }
  end

  def cookie_names
    page
      .driver
      .with_playwright_page { |pw_page| pw_page.context.cookies }
      .map { |cookie| cookie["name"] }
  end

  def evaluate(js)
    page.driver.with_playwright_page { |pw_page| pw_page.capybara_current_frame.evaluate(js) }
  end

  context "with the persistent profile driver" do
    def reset_with_requests_blocked
      BlockRequestsMiddleware.block_requests!
      page.reset!
    ensure
      BlockRequestsMiddleware.allow_requests!
    end

    before do
      unless SystemDrivers.use_headless_shell?(RSpec.current_example)
        skip "requires DISCOURSE_SYSTEM_TEST_HEADLESS_SHELL=1"
      end
    end

    it "clears history, storage, cookies, IndexedDB and permissions between examples" do
      visit "/"
      expect(page).to have_css("#main.ember-application")
      visit "/about"
      expect(page).to have_css("#main.ember-application")

      evaluate(<<~JS)
        () => {
          localStorage.setItem("iso_probe", "local");
          sessionStorage.setItem("iso_probe", "session");
          document.cookie = "iso_probe_cookie=1; path=/";
          window.name = "iso-probe";
          return true;
        }
      JS

      # CacheStorage is separate from service worker registrations.
      evaluate(<<~JS)
        async () => {
          const cache = await caches.open("iso_probe_cache");
          await cache.put("/", new Response("value"));
          return (await caches.keys()).length;
        }
      JS
      expect(evaluate("() => caches.keys()")).to include("iso_probe_cache")

      # Leave the IndexedDB connection open, like application code would.
      evaluate(<<~JS)
        async () => {
          const db = await new Promise((resolve, reject) => {
            const request = indexedDB.open("iso_probe", 1);
            request.onupgradeneeded = () => request.result.createObjectStore("kv");
            request.onsuccess = () => resolve(request.result);
            request.onerror = () => reject(request.error);
          });
          await new Promise((resolve, reject) => {
            const transaction = db.transaction("kv", "readwrite");
            transaction.objectStore("kv").put("value", "key");
            transaction.oncomplete = resolve;
            transaction.onerror = () => reject(transaction.error);
          });
          window.isoProbeDb = db;
          return true;
        }
      JS

      page.driver.with_playwright_page do |pw_page|
        pw_page.context.grant_permissions(["geolocation"])
        pw_page.context.add_cookies(
          [
            {
              name: "iso_probe_origin_a",
              value: "1",
              url: "http://test.localhost:#{Capybara.server_port}",
            },
            {
              name: "iso_probe_origin_b",
              value: "1",
              url: "http://127.0.0.1:#{Capybara.server_port}",
            },
          ],
        )
      end

      expect(
        evaluate("() => navigator.permissions.query({ name: 'geolocation' }).then((s) => s.state)"),
      ).to eq("granted")
      expect(cookie_names).to include("iso_probe_origin_a", "iso_probe_origin_b")
      expect(evaluate("() => history.length")).to be >= 2

      profile = profile_dir
      context = playwright_context

      reset_with_requests_blocked

      # A soft reset keeps the context and the profile on disk, which is the
      # whole point of the persistent profile.
      expect(context.closed?).to be(false)
      expect(playwright_context).to equal(context)
      expect(profile_dir).to eq(profile)
      expect(File.directory?(profile)).to be(true)

      # Neither a parked tab nor a replacement has history from the example.
      expect(evaluate("() => [history.length, window.name]")).to eq([1, ""])

      visit "/"
      expect(page).to have_css("#main.ember-application")

      expect(
        evaluate(
          "() => [localStorage.getItem('iso_probe'), " \
            "sessionStorage.getItem('iso_probe'), " \
            "document.cookie.includes('iso_probe')]",
        ),
      ).to eq([nil, nil, false])

      expect(evaluate("() => caches.keys()")).not_to include("iso_probe_cache")

      expect(
        evaluate("() => indexedDB.databases().then((dbs) => dbs.map((db) => db.name))"),
      ).not_to include("iso_probe")

      expect(
        evaluate("() => navigator.permissions.query({ name: 'geolocation' }).then((s) => s.state)"),
      ).to eq("prompt")

      expect(cookie_names).not_to include("iso_probe_origin_a", "iso_probe_origin_b")
    end

    it "signs the next example out by dropping the session cookie" do
      visit "/"
      anonymous_cookies = cookie_names

      sign_in(user)
      session_cookies = cookie_names - anonymous_cookies
      expect(session_cookies).not_to be_empty

      page.reset!
      visit "/"

      expect(cookie_names & session_cookies).to be_empty
      expect(page).to have_no_css(".header-dropdown-toggle.current-user")
    end

    it "creates the replacement page before closing a tab with a changed viewport" do
      visit "/"
      page.current_window.resize_to(900, 700)
      pages_when_created = []

      allow(browser).to receive(:create_page).and_wrap_original do |original, browser_context|
        pages_when_created << browser_context.pages.size
        original.call(browser_context)
      end

      reset_with_requests_blocked

      # One page (the previous one) must still be open while the replacement is
      # created, otherwise the persistent context loses its last window.
      expect(pages_when_created).to eq([1])
      expect(page.current_url).to eq("about:blank")
    end

    it "closes windows opened during the example" do
      visit "/"

      previous = page.driver.with_playwright_page { |pw_page| pw_page.context.pages }
      expect(previous.size).to eq(1)

      evaluate(<<~JS)
        () => {
          const link = document.createElement("a");
          link.href = "/about";
          link.target = "_blank";
          link.id = "iso-probe-new-tab";
          link.textContent = "open";
          link.style.cssText = "position: fixed; top: 0; left: 0; z-index: 99999";
          document.body.appendChild(link);
          return true;
        }
      JS
      find("#iso-probe-new-tab").click

      try_until_success do
        expect(page.driver.with_playwright_page { |pw_page| pw_page.context.pages.size }).to eq(2)
      end

      reset_with_requests_blocked

      remaining = page.driver.with_playwright_page { |pw_page| pw_page.context.pages }
      expect(remaining.size).to eq(1)
      expect(previous.map(&:guid)).not_to include(remaining.first.guid)
      expect(previous).to all(be_closed)
    end

    it "isolates new windows and discards their profiles on reset or browser exit" do
      visit "/safe-mode"
      primary_window = page.current_window
      primary_context = playwright_context
      primary_profile = profile_dir
      evaluate("() => localStorage.setItem('iso_probe_window', 'primary')")

      other_window = page.open_new_window(:window)
      expect(page.current_window).to eq(primary_window)
      expect(page.windows).to contain_exactly(primary_window, other_window)
      other_context = other_profile = nil

      page.within_window(other_window) do
        visit "/safe-mode"
        other_context = playwright_context
        other_profile = profile_dir
        expect(other_context).not_to equal(primary_context)
        expect(other_profile).not_to eq(primary_profile)
        expect(File.directory?(other_profile)).to be(true)
        expect(evaluate("() => localStorage.getItem('iso_probe_window')")).to be_nil
        evaluate("() => localStorage.setItem('iso_probe_window', 'other')")
      end

      expect(evaluate("() => localStorage.getItem('iso_probe_window')")).to eq("primary")
      page.reset!

      expect([primary_context, other_context]).to all(be_closed)
      expect([primary_profile, other_profile].select { |path| File.exist?(path) }).to be_empty

      visit "/safe-mode"
      expect(page.windows.size).to eq(1)
      expect(evaluate("() => localStorage.getItem('iso_probe_window')")).to be_nil

      relaunched_context = playwright_context
      relaunched_profile = profile_dir
      expect([primary_profile, other_profile]).not_to include(relaunched_profile)
      expect(File.directory?(relaunched_profile)).to be(true)

      # Closing the underlying browser emits a context close without calling
      # BrowserContext#close, so this exercises the browser-exit path.
      relaunched_context.browser.close
      expect(File.exist?(relaunched_profile)).to be(false)

      page.reset!
      visit "/safe-mode"

      expect(page.windows.size).to eq(1)
      expect(profile_dir).not_to eq(relaunched_profile)
    end

    it "hard resets after a download" do
      visit "/"
      profile = profile_dir
      context = playwright_context
      current_browser = browser
      downloads = Queue.new

      page.driver.with_playwright_page do |pw_page|
        pw_page.context.on("download", ->(download) { downloads << download })
      end

      evaluate(<<~JS)
        () => {
          const link = document.createElement("a");
          link.href = "/robots.txt";
          link.download = "iso-probe.txt";
          link.id = "iso-probe-download";
          link.textContent = "download";
          link.style.cssText = "position: fixed; top: 0; left: 0; z-index: 99999";
          document.body.appendChild(link);
          return true;
        }
      JS
      find("#iso-probe-download").click

      try_until_success { expect(downloads.size).to eq(1) }
      download = downloads.pop
      # Playwright deletes downloads when their context closes, so assert the
      # file before the hard reset that the download requires.
      path = download.path
      expect(download.failure).to be_nil
      expect(File.exist?(path)).to be(true)
      expect(path).to start_with(Downloads::FOLDER.to_s)

      try_until_success do
        expect(current_browser.instance_variable_get(:@context_downloaded)).to be(true)
      end

      page.reset!
      visit "/"

      expect(context.closed?).to be(true)
      expect(playwright_context).not_to equal(context)
      expect(profile_dir).not_to eq(profile)
      expect(File.exist?(profile)).to be(false)
    end

    it "hard resets when BrowserTime installed a fake clock",
       time: Time.utc(2020, 1, 1, 12, 0, 0) do
      visit "/"

      expect(evaluate("() => setTimeout.toString()")).not_to include("[native code]")
      expect(evaluate("() => Date.now()")).to be_within(86_400_000).of(
        Time.utc(2020, 1, 1, 12).to_i * 1_000,
      )

      profile = profile_dir
      context = playwright_context

      page.reset!
      visit "/"

      expect(context.closed?).to be(true)
      expect(profile_dir).not_to eq(profile)
      expect(File.exist?(profile)).to be(false)
      # A fake clock belongs to the discarded context, not the next example.
      expect(evaluate("() => setTimeout.toString()")).to include("[native code]")
      expect(evaluate("() => Date.now()")).to be_within(3_600_000).of(
        Process.clock_gettime(Process::CLOCK_REALTIME) * 1_000,
      )
    end
  end

  context "when an artifact is recorded", :video do
    it "disables the soft reset so the recording is complete" do
      visit "/"
      context = playwright_context

      expect(page.driver.send(:soft_reset_enabled?)).to be(false)
      page.reset!

      expect(context.closed?).to be(true)
    end
  end

  it "disables the soft reset when a trace callback is registered" do
    page.driver.on_save_trace { |_path| }
    expect(page.driver.send(:soft_reset_enabled?)).to be(false)
  ensure
    page.driver.instance_variable_set(:@callback_on_save_trace, nil)
  end

  it "keeps trace and video examples off the persistent profile driver" do
    expect(SystemDrivers.use_headless_shell?(double(metadata: { trace: true }))).to be(false)
    expect(SystemDrivers.use_headless_shell?(double(metadata: { video: true }))).to be(false)
  end
end
