# frozen_string_literal: true

require "tmpdir"
require "zip"

RSpec.describe "Persistent system browser" do
  around(:each) do |example|
    previous_browser_cache = ENV["DISCOURSE_SYSTEM_BROWSER_CACHE"]
    ENV["DISCOURSE_SYSTEM_BROWSER_CACHE"] = "1"
    example.run
  ensure
    ENV["DISCOURSE_SYSTEM_BROWSER_CACHE"] = previous_browser_cache
  end

  fab!(:user)
  fab!(:post)

  let(:topic_page) { PageObjects::Pages::Topic.new }

  it "lets a visitor start a fresh page with cleared authentication and browser storage" do
    sign_in(user)
    visit("/latest")
    expect(page.driver).to be_a(SystemPersistentDriver)
    previous_page = page.driver.with_playwright_page(&:itself)
    previous_context = previous_page.context
    previous_context.grant_permissions(["geolocation"], origin: previous_page.url)
    expect(previous_page.evaluate(<<~JS)).to eq(true)
      async () => {
        window.previousExample = true;
        document.cookie = 'persistent_test_cookie=present; path=/';
        localStorage.setItem('persistent_test_local', 'present');
        sessionStorage.setItem('persistent_test_session', 'present');
        await new Promise((resolve, reject) => {
          const request = indexedDB.open('persistent_test_database', 1);
          request.onupgradeneeded = () => request.result.createObjectStore('sentinel');
          request.onerror = () => reject(request.error);
          request.onsuccess = () => { request.result.close(); resolve(); };
        });
        return (await navigator.permissions.query({ name: 'geolocation' })).state === 'granted' &&
          (await indexedDB.databases()).some(database => database.name === 'persistent_test_database');
      }
    JS

    Capybara.reset_sessions!
    visit("/latest")

    expect(page).to have_css(".login-button")
    current_page = page.driver.with_playwright_page(&:itself)
    expect(previous_page.closed?).to eq(true)
    expect(current_page.context).to equal(previous_context)
    expect(current_page.evaluate(<<~JS)).to eq(true)
      async () => {
        return window.previousExample === undefined &&
          !document.cookie.includes('persistent_test_cookie=') &&
          localStorage.getItem('persistent_test_local') === null &&
          sessionStorage.getItem('persistent_test_session') === null &&
          !(await indexedDB.databases()).some(database => database.name === 'persistent_test_database') &&
          (await navigator.permissions.query({ name: 'geolocation' })).state !== 'granted';
      }
    JS
    topic_page.visit_topic(post.topic)
    expect(topic_page).to have_post_content(post_number: 1, content: post.raw)
  end

  it "drops context scripts, routes, headers, and listeners before the next visitor" do
    visit("/latest")
    previous_page = page.driver.with_playwright_page(&:itself)
    previous_context = previous_page.context
    route_calls = 0
    previous_context.add_init_script(script: "window.contextExample = true")
    previous_context.set_extra_http_headers("X-Persistent-Example" => "present")
    previous_context.route(
      "**/latest",
      ->(route, _request) do
        route_calls += 1
        route.continue
      end,
    )
    previous_context.on("page", ->(_page) { route_calls += 100 })
    visit("/latest")
    expect(page.evaluate_script("window.contextExample")).to eq(true)
    expect(route_calls).to eq(1)

    Capybara.reset_sessions!
    visit("/latest")

    expect(page).to have_css(".login-button")
    expect(previous_context.closed?).to eq(true)
    expect(page.evaluate_script("window.contextExample === undefined")).to eq(true)
    expect(route_calls).to eq(1)
    current_page = page.driver.with_playwright_page(&:itself)
    request = current_page.expect_request("**/latest") { visit("/latest") }
    expect(request.headers).not_to have_key("x-persistent-example")
  end

  it "restores the native clock and closes extra windows on reset" do
    visit("/latest")
    previous_page = page.driver.with_playwright_page(&:itself)
    previous_context = previous_page.context
    BrowserTime.freeze(page, Time.utc(2001, 1, 1))
    expect(page.evaluate_script("new Date().getUTCFullYear()")).to eq(2001)
    new_window = open_new_window(:window)
    expect(page.windows.length).to eq(2)
    within_window(new_window) do
      visit("/latest")
      expect(page).to have_css(".login-button")
    end

    Capybara.reset_sessions!
    visit("/latest")

    expect(page.windows.length).to eq(1)
    expect(previous_context.closed?).to eq(true)
    expect(new_window.closed?).to eq(true)
    expect(page.evaluate_script("new Date().getUTCFullYear()")).to eq(Time.now.utc.year)
    expect(page).to have_css(".login-button")
  end

  it "keeps JavaScript error listeners attached to their own fresh page" do
    visit("/latest")
    previous_page = page.driver.with_playwright_page(&:itself)
    old_errors = []
    previous_page.on("pageerror", ->(error) { old_errors << error.message })

    Capybara.reset_sessions!
    visit("/latest")

    current_page = page.driver.with_playwright_page(&:itself)
    $playwright_logger = PlaywrightLogger.new(current_page)
    new_errors = []
    current_page.on("pageerror", ->(error) { new_errors << error.message })
    current_page.evaluate(
      "() => { setTimeout(() => { throw new Error('persistent browser error check'); }, 0); }",
    )
    try_until_success { expect(new_errors).to include("persistent browser error check") }
    expect($playwright_logger.logs).to include(
      a_hash_including(
        level: "error",
        message: "persistent browser error check",
        source: "pageerror-api",
      ),
    )
    expect(old_errors).to be_empty
    expect(page).to have_css(".login-button")
  end

  it "keeps a saved download while discarding the browser download context" do
    visit("/latest")
    previous_page = page.driver.with_playwright_page(&:itself)
    previous_context = previous_page.context
    Dir.mktmpdir do |directory|
      saved_path = File.join(directory, "download.txt")
      download = previous_page.expect_download { previous_page.evaluate(<<~JS) }
          () => {
            const link = document.createElement('a');
            link.href = URL.createObjectURL(new Blob(['persistent browser download']));
            link.download = 'download.txt';
            link.click();
          }
        JS
      download.save_as(saved_path)
      expect(File.read(saved_path)).to eq("persistent browser download")

      Capybara.reset_sessions!
      visit("/latest")

      expect(previous_context.closed?).to eq(true)
      expect(File.read(saved_path)).to eq("persistent browser download")
      expect(page).to have_css(".login-button")
    end
  end

  it "records both native visits when a trace spans a soft reset" do
    Dir.mktmpdir do |directory|
      trace_path = File.join(directory, "visits.zip")
      driver = page.driver
      previous_context = driver.with_playwright_page(&:context)
      driver.start_tracing(snapshots: true)
      visit("/latest")
      expect(page).to have_css(".login-button")
      before_reset = SystemPersistentBrowser.statistics

      Capybara.reset_sessions!
      topic_page.visit_topic(post.topic)

      expect(topic_page).to have_post_content(post_number: 1, content: post.raw)
      expect(driver.with_playwright_page(&:context)).to equal(previous_context)
      expect(SystemPersistentBrowser.statistics[:reused_resets]).to be >
        before_reset[:reused_resets]
      driver.stop_tracing(path: trace_path)
      Zip::File.open(trace_path) do |zip|
        trace =
          zip
            .entries
            .filter_map { |entry| zip.read(entry.name) if entry.name.end_with?(".trace") }
            .join
        expect(trace).to include("/latest", post.topic.url)
      end
    end
  end

  it "saves screenshots, videos, and traces through the existing artifact callbacks" do
    driver = page.driver
    Dir.mktmpdir do |directory|
      screenshots = []
      videos = []
      traces = []
      driver.on_save_raw_screenshot_before_reset { |bytes| screenshots << bytes }
      driver.on_save_screenrecord do |path|
        target = File.join(directory, "recording-#{videos.length}.webm")
        FileUtils.cp(path, target)
        videos << target
      end
      driver.on_save_trace do |path|
        target = File.join(directory, "trace-#{traces.length}.zip")
        FileUtils.cp(path, target)
        traces << target
      end
      driver.reset!
      screenshots.clear

      visit("/latest")
      expect(page).to have_css(".login-button")
      recorded_browser = driver.with_playwright_page { |browser_page| browser_page.context.browser }
      driver.reset!

      expect(recorded_browser.connected?).to eq(true)
      expect(screenshots.length).to eq(1)
      expect(screenshots.first).to start_with("\x89PNG".b)
      expect(videos.length).to eq(1)
      expect(File.size(videos.first)).to be_positive
      expect(traces.length).to eq(1)
      Zip::File.open(traces.first) do |zip|
        expect(zip.entries.any? { |entry| entry.name.end_with?(".trace") }).to eq(true)
      end
    ensure
      driver.on_save_raw_screenshot_before_reset
      driver.on_save_screenrecord
      driver.on_save_trace
    end
  end
end
